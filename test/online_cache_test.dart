// Checks for the streaming cache.
//
//   flutter test test/online_cache_test.dart
//
// The cache is what turns a streamed track into a real file, which is how it
// keeps working offline and becomes eligible for the direct-USB output path.
// The interesting cases are the failure ones: a half-finished download must
// never be mistaken for a cached track, and eviction must not exceed its cap.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/models/song.dart';
import 'package:spark/services/online_cache_service.dart';

Song _streamedSong({
  String id = 'audius:abc',
  String title = 'Cached Track',
}) {
  return Song(
    id: id,
    title: title,
    artist: 'Some Artist',
    duration: const Duration(seconds: 180),
    fileType: 'MP3',
    albumArt: 'https://example.test/cover.jpg',
    filePath: 'https://api.audius.co/v1/tracks/abc/stream',
    isExternal: true,
    sourceType: 'audius',
    remoteId: 'abc',
  );
}

/// Serves [payload] for every request.
http.Client _serving(List<int> payload, {int status = 200}) {
  return MockClient.streaming((request, bodyStream) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([payload]),
      status,
      contentLength: payload.length,
    );
  });
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('spark_cache_test');
  });

  tearDown(() async {
    // Downloads kick off an unawaited eviction pass, which can still hold the
    // index file open. Give it a moment, then tolerate a locked directory --
    // the temp path is disposable and the assertions have already run.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Left in the OS temp directory.
    }
  });

  OnlineCacheService build({
    http.Client? client,
    int maxBytes = OnlineCacheService.kDefaultMaxBytes,
  }) {
    return OnlineCacheService(
      directory: dir,
      client: client ?? _serving(List.filled(1000, 7)),
      maxBytes: maxBytes,
    );
  }

  group('cacheability', () {
    test('only stream sources with an http url are cached', () {
      expect(OnlineCacheService.isCacheable(_streamedSong()), isTrue);

      final local = Song(
        id: '1',
        title: 'Local',
        artist: 'A',
        duration: Duration.zero,
        fileType: 'MP3',
        filePath: '/sdcard/Music/a.mp3',
      );
      expect(OnlineCacheService.isCacheable(local), isFalse);

      // A stream source whose path is already a file is not re-cached.
      final alreadyLocal = _streamedSong().copyWith(
        filePath: '/data/cache/x.mp3',
      );
      expect(OnlineCacheService.isCacheable(alreadyLocal), isFalse);
    });

    test('ensureCached ignores a non-cacheable song', () async {
      final service = build();
      final local = Song(
        id: '1',
        title: 'Local',
        artist: 'A',
        duration: Duration.zero,
        fileType: 'MP3',
        filePath: '/sdcard/Music/a.mp3',
      );
      expect(await service.ensureCached(local), isNull);
      expect(await service.count(), 0);
    });
  });

  group('downloading', () {
    test('writes a readable file and records it', () async {
      final payload = List<int>.generate(5000, (i) => i % 256);
      final service = build(client: _serving(payload));
      final song = _streamedSong();

      final file = await service.ensureCached(song);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), payload.length);

      expect(await service.isCached(song), isTrue);
      expect(await service.cachedPath(song), file.path);
      expect(await service.totalBytes(), payload.length);

      final entries = await service.entries();
      expect(entries, hasLength(1));
      expect(entries.single.title, 'Cached Track');
      expect(entries.single.sourceType, 'audius');
    });

    test('reports progress', () async {
      final payload = List<int>.filled(4096, 1);
      final service = build(client: _serving(payload));
      final progress = <int>[];

      await service.ensureCached(
        _streamedSong(),
        onProgress: (received, total) {
          progress.add(received);
          expect(total, payload.length);
        },
      );

      expect(progress, isNotEmpty);
      expect(progress.last, payload.length);
    });

    test('a second call reuses the cached file', () async {
      var requests = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        requests++;
        final payload = List<int>.filled(1000, 3);
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([payload]),
          200,
          contentLength: payload.length,
        );
      });
      final service = build(client: client);
      final song = _streamedSong();

      await service.ensureCached(song);
      await service.ensureCached(song);
      expect(requests, 1, reason: 'the cache must not refetch what it has');
    });

    test('concurrent calls share one download', () async {
      var requests = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final payload = List<int>.filled(1000, 3);
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([payload]),
          200,
          contentLength: payload.length,
        );
      });
      final service = build(client: client);

      await Future.wait([
        service.ensureCached(_streamedSong()),
        service.ensureCached(_streamedSong()),
      ]);
      expect(requests, 1);
    });

    test('an error status leaves nothing behind', () async {
      final service = build(client: _serving(List.filled(10, 1), status: 500));
      final song = _streamedSong();

      expect(await service.ensureCached(song), isNull);
      expect(await service.isCached(song), isFalse);
      expect(await service.count(), 0);

      // And no stray .part file is left for a later run to trip over.
      final leftovers = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.part'));
      expect(leftovers, isEmpty);
    });

    test('an empty body is treated as a failure', () async {
      final service = build(client: _serving(const []));
      expect(await service.ensureCached(_streamedSong()), isNull);
      expect(await service.count(), 0);
    });
  });

  group('persistence', () {
    test('the index survives a new instance', () async {
      final song = _streamedSong();
      await build().ensureCached(song);

      // A fresh service over the same directory models an app relaunch.
      final reloaded = build();
      expect(await reloaded.isCached(song), isTrue);
      final path = await reloaded.cachedPath(song);
      expect(path, isNotNull);
      expect(await File(path!).exists(), isTrue);
    });

    test('entries whose file vanished are dropped', () async {
      final song = _streamedSong();
      final service = build();
      final file = await service.ensureCached(song);
      await file!.delete();

      final reloaded = build();
      expect(await reloaded.isCached(song), isFalse);
      expect(await reloaded.count(), 0);
    });
  });

  group('eviction', () {
    test('stays under the cap and keeps the newest', () async {
      const payloadSize = 1000;
      final service = build(maxBytes: 2500);

      // Three 1000-byte tracks against a 2500-byte cap: one must go.
      for (var i = 0; i < 3; i++) {
        await service.ensureCached(
          _streamedSong(id: 'audius:t$i', title: 'Track $i'),
          // ignore: avoid_types_on_closure_parameters
        );
        // Space the timestamps so "least recently used" is unambiguous.
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await service.evictIfNeeded();

      expect(await service.totalBytes(), lessThanOrEqualTo(2500));
      expect(await service.count(), lessThan(3));

      // The most recent track is the one that survives.
      final remaining = await service.entries();
      expect(remaining.map((e) => e.songId), contains('audius:t2'));
      expect(remaining.first.bytes, payloadSize);
    });

    test('does nothing while under the cap', () async {
      final service = build(maxBytes: 10 * 1024 * 1024);
      await service.ensureCached(_streamedSong());
      await service.evictIfNeeded();
      expect(await service.count(), 1);
    });
  });

  group('removal', () {
    test('remove drops one entry and its file', () async {
      final service = build();
      final song = _streamedSong();
      final file = await service.ensureCached(song);

      await service.remove(song);
      expect(await service.isCached(song), isFalse);
      expect(await file!.exists(), isFalse);
      expect(await service.count(), 0);
    });

    test('clear empties everything, including part files', () async {
      final service = build();
      await service.ensureCached(_streamedSong(id: 'a', title: 'A'));
      await service.ensureCached(_streamedSong(id: 'b', title: 'B'));
      await File('${dir.path}/online_cache/stray.mp3.part').writeAsString('x');

      await service.clear();

      expect(await service.count(), 0);
      expect(await service.totalBytes(), 0);
      final leftovers = Directory('${dir.path}/online_cache')
          .listSync()
          .whereType<File>()
          // The index itself is expected to remain.
          .where((f) => !f.path.endsWith('index.json'));
      expect(leftovers, isEmpty);
    });
  });

  group('file naming', () {
    test('produces a filesystem-safe name from the song id', () async {
      final service = build();
      final song = _streamedSong(id: 'jamendo:1111548');
      final file = await service.ensureCached(song);
      expect(file, isNotNull);

      // Check the name itself, not the whole path: the temp directory on
      // Windows legitimately contains a drive-letter colon, and the path is
      // built with forward slashes regardless of platform.
      final name = file!.uri.pathSegments.last;
      expect(name, 'jamendo_1111548.mp3');
      expect(name.contains(':'), isFalse);
    });
  });
}
