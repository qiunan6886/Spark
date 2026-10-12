// Probe for OnlineLyricsService, run with:
//   dart run tools/lyrics_probe.dart
//
// Verifies the auto-download path end to end (network + JSON + LRC parsing)
// without needing a song on the device that lrclib actually has lyrics for.
import 'package:spark/services/online_lyrics_service.dart';

Future<void> main() async {
  final service = OnlineLyricsService();

  for (final probe in const [
    ('Queen', 'Bohemian Rhapsody'),
    ('Adele', 'Hello'),
    ('Samsung', 'Over the Horizon'),
  ]) {
    final (artist, title) = probe;
    final result = await service.fetchExact(artist: artist, title: title);
    if (result == null) {
      print('$artist / $title -> no exact match');
      continue;
    }
    print(
      '$artist / $title -> id=${result.id} '
      'instrumental=${result.instrumental} '
      'synced=${result.hasSyncedLyrics} plain=${result.hasPlainLyrics} '
      'lines=${result.lineCount}',
    );
    if (result.hasSyncedLyrics) {
      final first = result.syncedLyrics!
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(3)
          .join(' | ');
      print('    first synced lines: $first');
    }
  }
}
