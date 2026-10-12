// Widget checks for the Downloads pane.
//
//   flutter test test/downloads_pane_test.dart
//
// The pane is the only place the streaming cache becomes visible, so it needs
// to build, list what is held and report the space used. It is tested on its
// own rather than through LibraryScreen: the pane is what changed, and pumping
// the whole tab drags in the scanner, the mini player and the nav bar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/features/library/downloads_pane.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/services/online_cache_service.dart';

/// Stands in for the real cache so the pane renders known content.
class _FakeCache extends OnlineCacheService {
  _FakeCache(this._entries);

  final List<OnlineCacheEntry> _entries;

  @override
  Future<List<OnlineCacheEntry>> entries() async => _entries;

  @override
  Future<List<Song>> cachedSongs() async => [
    for (final entry in _entries) entry.toSong('/cache/${entry.fileName}'),
  ];
}

OnlineCacheEntry _entry(String id, String title, int bytes) {
  return OnlineCacheEntry(
    songId: id,
    fileName: '$id.mp3',
    bytes: bytes,
    title: title,
    artist: 'Streaming Artist',
    addedAt: DateTime(2026),
    lastUsed: DateTime(2026),
  );
}

Widget _wrap(OnlineCacheService cache) {
  return ProviderScope(
    overrides: [onlineCacheServiceProvider.overrideWithValue(cache)],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(body: DownloadsPane()),
    ),
  );
}

void main() {
  testWidgets('lists cached tracks with the space they use', (tester) async {
    final cache = _FakeCache([
      _entry('audius:a', 'Cached One', 5 * 1024 * 1024),
      _entry('jamendo:b', 'Cached Two', 3 * 1024 * 1024),
    ]);
    await tester.pumpWidget(_wrap(cache));
    await tester.pumpAndSettle();

    expect(find.text('Cached One'), findsOneWidget);
    expect(find.text('Cached Two'), findsOneWidget);
    // 8 MB total, formatted rather than shown as raw bytes.
    expect(find.text('已占用 8.0 MB'), findsOneWidget);
  });

  testWidgets('shows a hint when nothing is cached', (tester) async {
    await tester.pumpWidget(_wrap(_FakeCache(const [])));
    await tester.pumpAndSettle();

    expect(find.text('还没有离线内容'), findsOneWidget);
  });

  group('formatBytes', () {
    test('scales through the units', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(512 * 1024), '512 KB');
      expect(formatBytes(8 * 1024 * 1024), '8.0 MB');
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
    });
  });
}
