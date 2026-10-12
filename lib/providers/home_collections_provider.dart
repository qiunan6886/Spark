import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import 'favorites_provider.dart';
import 'home_feed_provider.dart';
import 'online_music_provider.dart';
import 'songs_provider.dart';

/// The tracks played most recently, newest first.
///
/// `RecentlyPlayedEntry` already carries a resolved `Song` and drops rows whose
/// file is gone, so this only has to remove repeats of the same track.
///
/// Streamed tracks never appear: `recordPlay` parses the song id as an int and
/// bails out on anything else, so only local songs are recorded. That is the
/// behaviour we want -- a stream is not part of the library's history.
final recentlyPlayedProvider = FutureProvider.autoDispose<List<Song>>((
  ref,
) async {
  final entries = await ref
      .watch(recentlyPlayedRepositoryProvider)
      .getRecentHistory(limit: 40);

  final songs = <Song>[];
  final seen = <String>{};
  for (final entry in entries) {
    if (!seen.add(entry.song.id)) continue;
    songs.add(entry.song);
  }
  return songs;
});

/// A set of tracks surfaced on Home as one stacked card.
@immutable
class HomeCollection {
  const HomeCollection({
    required this.id,
    required this.songs,
    this.builtFromLibrary = true,
  });

  /// Stable identity, also used to pick the localised title.
  final String id;
  final List<Song> songs;

  /// False when the tracks came from the streaming catalogues, which decides
  /// whether the card can promise offline playback.
  final bool builtFromLibrary;

  bool get isEmpty => songs.isEmpty;
}

/// How many tracks a generated collection holds.
const int kCollectionSize = 25;

/// A pick that stays the same all day and changes tomorrow.
///
/// Seeded from the date rather than `Random()` so the card does not reshuffle
/// on every rebuild -- a "daily" mix that changes each time you look at it is
/// just a random list.
final dailyMixProvider = FutureProvider.autoDispose<HomeCollection>((
  ref,
) async {
  final library = ref.watch(songsProvider).value?.songs ?? const <Song>[];
  if (library.isEmpty) {
    return const HomeCollection(id: 'daily', songs: []);
  }

  final shuffled = [...library]..shuffle(Random(daySeed(DateTime.now())));
  return HomeCollection(
    id: 'daily',
    songs: shuffled.take(kCollectionSize).toList(),
  );
});

/// Suggestions built from what the listener actually plays.
///
/// Artists are ranked by play count with favourites weighted in, then tracks
/// from those artists are suggested *excluding* the ones already favourited --
/// the point is to surface something new next to what is loved. With no history
/// at all it falls back to the streaming catalogues, so a fresh install still
/// gets something to press.
final forYouProvider = FutureProvider.autoDispose<HomeCollection>((ref) async {
  final library = ref.watch(songsProvider).value?.songs ?? const <Song>[];
  final favorites =
      ref.watch(favoritesProvider).value?.favoriteSongs ?? const <Song>[];
  final counts = await ref.watch(playCountsProvider.future);

  final byId = {for (final song in library) song.id: song};

  final affinity = <String, int>{};
  for (final entry in counts.entries) {
    final song = byId[entry.key];
    if (song == null) continue;
    affinity.update(song.artist, (v) => v + entry.value, ifAbsent: () => entry.value);
  }
  // A like is a stronger signal than a single play.
  for (final song in favorites) {
    affinity.update(song.artist, (v) => v + 5, ifAbsent: () => 5);
  }

  if (affinity.isEmpty) {
    return HomeCollection(
      id: 'forYou',
      songs: _onlineFallback(ref),
      builtFromLibrary: false,
    );
  }

  final ranked = affinity.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topArtists = {for (final e in ranked.take(8)) e.key};
  final favoriteIds = {for (final song in favorites) song.id};

  final picks = <Song>[];
  for (final song in library) {
    if (picks.length >= kCollectionSize) break;
    if (topArtists.contains(song.artist) && !favoriteIds.contains(song.id)) {
      picks.add(song);
    }
  }

  // Top up from favourites so the card is never nearly empty, then from the
  // library at large if there is not enough of either.
  if (picks.length < kCollectionSize) {
    final chosen = {for (final song in picks) song.id};
    for (final song in favorites) {
      if (picks.length >= kCollectionSize) break;
      if (chosen.add(song.id)) picks.add(song);
    }
    for (final song in library) {
      if (picks.length >= kCollectionSize) break;
      if (chosen.add(song.id)) picks.add(song);
    }
  }

  return HomeCollection(id: 'forYou', songs: picks);
});

/// Streaming picks, used when the device has no library or no history.
List<Song> _onlineFallback(Ref ref) {
  final songs = <Song>[];
  final audius = ref.watch(audiusFeedProvider).value;
  if (audius != null) {
    for (final track in audius.items.take(12)) {
      songs.add(track.toSong());
    }
  }
  final jamendo = ref.watch(jamendoFeedProvider).value;
  if (jamendo != null) {
    for (final track in jamendo.items.take(12)) {
      songs.add(track.toSong());
    }
  }
  return songs;
}

/// `yyyyMMdd` as an int, so the same day always seeds the same shuffle.
/// `yyyyMMdd` as an int, so the same day always seeds the same shuffle.
///
/// Exposed for tests: a daily mix that reshuffles on every rebuild would just
/// be a random list, and that regression is invisible on screen.
int daySeed(DateTime now) => now.year * 10000 + now.month * 100 + now.day;
