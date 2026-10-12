import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../services/lyrics_service.dart';
import '../services/online_lyrics_service.dart';

final lyricsServiceProvider = Provider<LyricsService>((ref) => LyricsService());

final onlineLyricsServiceProvider = Provider<OnlineLyricsService>(
  (ref) => OnlineLyricsService(),
);

/// Lyrics for a song, downloaded on first look and kept afterwards.
///
/// Order of resolution:
///   1. a `.lrc` the user linked, then lyrics embedded in the file's tags, then
///      a `<name>.lrc` sidecar next to the audio (all handled by
///      [LyricsService.loadLyricsForSong]);
///   2. lrclib.net, matched on artist + title + album + duration.
///
/// Anything fetched in step 2 is written back beside the song, so each track is
/// downloaded once rather than on every play. Keyed by [Song] (which compares
/// by id) so switching tracks re-resolves without re-fetching on rebuilds.
final songLyricsProvider = FutureProvider.autoDispose.family<LyricsData?, Song>(
  (ref, song) async {
    final service = ref.watch(lyricsServiceProvider);

    final local = await service.loadLyricsForSong(song);
    if (local != null && local.lines.isNotEmpty) {
      return local;
    }

    final onlineService = ref.watch(onlineLyricsServiceProvider);

    // Exact match first: it is the only query lrclib guarantees is the right
    // recording. A miss is common though (differing album/duration metadata), so
    // fall back to a search and take the best candidate that actually has words.
    var content = '';
    final exact = await onlineService.fetchExact(
      artist: song.artist,
      title: song.title,
      album: song.album,
      duration: song.duration,
    );
    if (exact != null && !exact.instrumental) {
      content = exact.bestLyrics.trim();
    }

    if (content.isEmpty) {
      final candidates = await onlineService.search(
        artist: song.artist,
        title: song.title,
      );
      // Prefer a result that has synced lyrics: it can highlight the current
      // line, while plain text cannot.
      final ranked = [...candidates]
        ..sort((a, b) {
          int score(OnlineLyricsResult r) {
            if (r.instrumental) return 0;
            return r.hasSyncedLyrics ? 2 : 1;
          }

          return score(b).compareTo(score(a));
        });
      for (final candidate in ranked) {
        if (candidate.instrumental) continue;
        final text = candidate.bestLyrics.trim();
        if (text.isNotEmpty) {
          content = text;
          break;
        }
      }
    }

    if (content.isEmpty) return null;

    try {
      final saved = await service.saveLyricsForSong(
        song: song,
        content: content,
      );
      return saved.data;
    } catch (_) {
      // Writing beside the song fails on read-only locations (a SAF tree, for
      // instance). Showing what we already fetched beats showing nothing.
      return service.parseLyricsText(content, source: 'lrclib.net');
    }
  },
);
