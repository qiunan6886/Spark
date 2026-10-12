// Live check of AudiusService against the real API.
//
//   flutter test test/audius_live_test.dart
//
// This is deliberately a Flutter test rather than a `dart run` script: the
// service pulls in devLog, which imports Flutter, so a plain Dart process
// cannot load it. Running the real class beats re-implementing the HTTP calls
// in a probe, because it also exercises the JSON mapping and Song conversion.
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/services/audius_service.dart';

void main() {
  final service = AudiusService();

  /// Audius intermittently answers with an empty list under load, so a single
  /// empty page says nothing about correctness. Retry before concluding.
  Future<List<AudiusTrack>> loadWithRetry(
    Future<List<AudiusTrack>> Function() load, {
    required String label,
  }) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final tracks = await load();
      if (tracks.isNotEmpty) return tracks;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    // ignore: avoid_print
    print('  $label stayed empty across 4 attempts');
    return const [];
  }

  test('trending returns playable tracks', () async {
    final tracks = await loadWithRetry(
      () => service.trending(limit: 5),
      label: 'Audius trending',
    );
    expect(tracks, isNotEmpty, reason: 'Audius trending returned nothing');

    for (final track in tracks) {
      expect(track.id, isNotEmpty);
      expect(track.title, isNotEmpty);
      expect(track.artist, isNotEmpty);
      expect(track.duration.inSeconds, greaterThan(0));

      final song = track.toSong();
      expect(song.isNetworkSource, isTrue);
      expect(song.filePath, startsWith('https://api.audius.co/v1/tracks/'));
      expect(song.filePath, contains('/stream'));
      expect(song.sourceType, 'audius');

      // ignore: avoid_print
      print(
        '  ${track.artist} - ${track.title} '
        '(${track.duration.inSeconds}s, art=${track.artworkUrl != null})',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('search returns matches', () async {
    final tracks = await loadWithRetry(
      () => service.search('lofi', limit: 5),
      label: 'Audius search',
    );
    expect(tracks, isNotEmpty, reason: 'Audius search returned nothing');

    for (final track in tracks) {
      expect(track.id, isNotEmpty);
      // ignore: avoid_print
      print('  ${track.artist} - ${track.title}');
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('empty query short-circuits without a request', () async {
    final tracks = await service.search('   ');
    expect(tracks, isEmpty);
  });
}
