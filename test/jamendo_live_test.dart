// Live check of JamendoService against the real API.
//
//   flutter test test/jamendo_live_test.dart
//
// Uses the Client ID the build ships with. Jamendo rate-limits bursts by
// answering with an empty list, so this makes only a couple of requests and
// treats "no results" as a soft failure with a clear message rather than a
// hard assertion that would look like a code defect.
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/providers/online_music_provider.dart';
import 'package:spark/services/jamendo_service.dart';

void main() {
  final service = JamendoService(clientId: kDefaultJamendoClientId);

  /// Jamendo rate-limits bursts by answering `success` with zero results, so a
  /// single empty page says nothing about correctness. Retry before concluding.
  Future<List<JamendoTrack>> trendingWithRetry() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final tracks = await service.trending(limit: 5);
      if (tracks.isNotEmpty) return tracks;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    return const [];
  }

  test('client id is configured', () {
    expect(kDefaultJamendoClientId, isNotEmpty);
    expect(service.isConfigured, isTrue);
  });

  test('trending returns tracks with streamable audio', () async {
    final tracks = await trendingWithRetry();
    expect(
      tracks,
      isNotEmpty,
      reason: 'Jamendo trending stayed empty across 4 attempts (rate limited?)',
    );

    for (final track in tracks) {
      expect(track.id, isNotEmpty);
      expect(track.title, isNotEmpty);
      expect(track.artist, isNotEmpty);
      expect(track.audioUrl, startsWith('https://'));

      final song = track.toSong();
      expect(song.isNetworkSource, isTrue);
      expect(song.sourceType, 'jamendo');
      expect(song.filePath, track.audioUrl);

      // ignore: avoid_print
      print(
        '  ${track.artist} - ${track.title} '
        '(${track.duration.inSeconds}s, art=${track.artworkUrl != null}, '
        'cc=${track.licenseUrl?.isNotEmpty ?? false})',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('empty client id disables the source without a request', () async {
    final unconfigured = JamendoService(clientId: '   ');
    expect(unconfigured.isConfigured, isFalse);
    expect(await unconfigured.trending(), isEmpty);
    expect(await unconfigured.search('anything'), isEmpty);
  });

  test('offset paging returns different tracks', () async {
    final first = await trendingWithRetry();
    if (first.isEmpty) return; // rate limited; covered by the test above

    for (var attempt = 0; attempt < 4; attempt++) {
      final second = await service.trending(limit: 5, offset: 5);
      if (second.isNotEmpty) {
        // Compare the whole pages, not just the first track: the catalogue's
        // ordering is not perfectly stable between requests, so an overlap is
        // not a failure -- but an offset that is silently ignored returns the
        // exact same page, which is the bug worth catching.
        expect(
          second.map((t) => t.id).toList(),
          isNot(first.map((t) => t.id).toList()),
          reason: 'offset=5 must not return the first page again',
        );
        // ignore: avoid_print
        print(
          '  page 2 starts at: ${second.first.artist} - ${second.first.title}',
        );
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }, timeout: const Timeout(Duration(seconds: 120)));
}
