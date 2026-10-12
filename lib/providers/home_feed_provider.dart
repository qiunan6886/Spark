import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/recently_played_repository.dart';
import '../data/repositories/song_repository.dart';
import 'favorites_provider.dart';
import 'songs_provider.dart';

/// Which quick filter the home feed is showing.
enum HomeFilter { all, newReleases, trending, liked }

final recentlyPlayedRepositoryProvider = Provider<RecentlyPlayedRepository>(
  (ref) => RecentlyPlayedRepository(),
);

/// How many times each song has been played, keyed by song id.
final playCountsProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(recentlyPlayedRepositoryProvider).getPlayCounts(),
);

/// The albums the home feed should show for [filter], in display order.
///
/// These used to be four decorative chips: the selected index only changed
/// which chip looked active, and the list below never changed. They now drive
/// real queries, so an empty result for a filter is a real "nothing matches"
/// and the screen says so rather than silently showing everything.
final homeFeedProvider = FutureProvider.autoDispose
    .family<List<AlbumGroup>, HomeFilter>((ref, filter) async {
      final albums = await ref.watch(songsByAlbumProvider.future);
      if (albums.isEmpty || filter == HomeFilter.all) return albums;

      switch (filter) {
        case HomeFilter.all:
          return albums;

        case HomeFilter.newReleases:
          // Newest album first, by the newest track it contains.
          final sorted = [...albums];
          sorted.sort((a, b) {
            final aDate = _newestDate(a);
            final bDate = _newestDate(b);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
          return sorted;

        case HomeFilter.trending:
          // Only albums the user has actually played, most-played first.
          final counts =
              await ref.watch(playCountsProvider.future) ?? const <String, int>{};
          final played = [
            for (final album in albums)
              if (_plays(album, counts) > 0) album,
          ]..sort((a, b) => _plays(b, counts).compareTo(_plays(a, counts)));
          return played;

        case HomeFilter.liked:
          final favorites = await ref.watch(favoritesProvider.future);
          return [
            for (final album in albums)
              if (album.songs.any((song) => favorites.isFavorite(song.id)))
                album,
          ];
      }
    });

DateTime? _newestDate(AlbumGroup album) {
  DateTime? newest;
  for (final song in album.songs) {
    final added = song.dateAdded;
    if (added == null) continue;
    if (newest == null || added.isAfter(newest)) newest = added;
  }
  return newest;
}

int _plays(AlbumGroup album, Map<String, int> counts) {
  var total = 0;
  for (final song in album.songs) {
    total += counts[song.id] ?? 0;
  }
  return total;
}
