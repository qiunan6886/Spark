import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

/// One cached track, as recorded in the cache index.
@immutable
class OnlineCacheEntry {
  const OnlineCacheEntry({
    required this.songId,
    required this.fileName,
    required this.bytes,
    required this.title,
    required this.artist,
    this.albumArt,
    this.genre,
    this.durationMs = 0,
    this.sourceType,
    this.remoteId,
    this.sourceUrl,
    required this.addedAt,
    required this.lastUsed,
  });

  final String songId;

  /// File name inside the cache directory. Stored relative so the cache keeps
  /// working if the app's data directory ever moves.
  final String fileName;
  final int bytes;
  final String title;
  final String artist;
  final String? albumArt;
  final String? genre;
  final int durationMs;
  final String? sourceType;
  final String? remoteId;
  final String? sourceUrl;
  final DateTime addedAt;
  final DateTime lastUsed;

  OnlineCacheEntry copyWith({DateTime? lastUsed}) => OnlineCacheEntry(
    songId: songId,
    fileName: fileName,
    bytes: bytes,
    title: title,
    artist: artist,
    albumArt: albumArt,
    genre: genre,
    durationMs: durationMs,
    sourceType: sourceType,
    remoteId: remoteId,
    sourceUrl: sourceUrl,
    addedAt: addedAt,
    lastUsed: lastUsed ?? this.lastUsed,
  );

  /// Rebuilds a playable [Song] pointed at the cached file.
  ///
  /// [filePath] is the local file, but `sourceType` is preserved so the app
  /// still knows this is a streaming track that happens to be cached.
  Song toSong(String absolutePath) => Song(
    id: songId,
    title: title,
    artist: artist,
    duration: Duration(milliseconds: durationMs),
    fileType: 'MP3',
    albumArt: albumArt,
    genre: genre,
    filePath: absolutePath,
    isExternal: true,
    sourceType: sourceType,
    remoteId: remoteId,
    dateAdded: addedAt,
  );

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'fileName': fileName,
    'bytes': bytes,
    'title': title,
    'artist': artist,
    'albumArt': albumArt,
    'genre': genre,
    'durationMs': durationMs,
    'sourceType': sourceType,
    'remoteId': remoteId,
    'sourceUrl': sourceUrl,
    'addedAt': addedAt.toIso8601String(),
    'lastUsed': lastUsed.toIso8601String(),
  };

  static OnlineCacheEntry? fromJson(Map<String, dynamic> json) {
    final songId = json['songId'];
    final fileName = json['fileName'];
    if (songId is! String || fileName is! String) return null;
    return OnlineCacheEntry(
      songId: songId,
      fileName: fileName,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? 'Unknown',
      artist: (json['artist'] as String?) ?? '',
      albumArt: json['albumArt'] as String?,
      genre: json['genre'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      sourceType: json['sourceType'] as String?,
      remoteId: json['remoteId'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      lastUsed:
          DateTime.tryParse(json['lastUsed'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// On-disk cache for streamed tracks.
///
/// Streaming works without this; the cache exists so a track that has been
/// played once starts instantly, keeps working offline, and -- because it is
/// then a real file on disk -- can use the direct-USB output path that the
/// streaming player cannot.
///
/// Entries are evicted least-recently-used once [maxBytes] is exceeded.
class OnlineCacheService {
  OnlineCacheService({
    Directory? directory,
    http.Client? client,
    this.maxBytes = kDefaultMaxBytes,
  }) : _directoryOverride = directory,
       _client = client ?? http.Client();

  /// Shared instance, so the player and the UI see one index.
  static OnlineCacheService instance = OnlineCacheService();

  /// 2 GB by default: room for a few hundred tracks, small enough that the
  /// cache cannot quietly consume a phone. Changeable from Settings; [noLimit]
  /// switches eviction off.
  static const int kDefaultMaxBytes = 2 * 1024 * 1024 * 1024;

  /// Value of [maxBytes] meaning "never evict".
  static const int noLimit = 0;

  /// Selectable limits, in bytes. Kept here so the picker and the service
  /// cannot drift apart.
  static const List<int> kLimitChoices = [
    500 * 1024 * 1024,
    1024 * 1024 * 1024,
    kDefaultMaxBytes,
    5 * 1024 * 1024 * 1024,
    noLimit,
  ];

  static const String _indexFileName = 'index.json';
  static const String _dirName = 'online_cache';

  /// Current cap in bytes, or [noLimit]. Mutable so Settings can change it
  /// without rebuilding the service.
  int maxBytes;

  final Directory? _directoryOverride;
  final http.Client _client;

  Directory? _directory;
  Map<String, OnlineCacheEntry> _index = {};
  bool _loaded = false;

  /// Downloads already running, so two taps do not fetch the same track twice.
  final Map<String, Future<File?>> _inFlight = {};

  Future<Directory> _dir() async {
    final cached = _directory;
    if (cached != null) return cached;
    final base =
        _directoryOverride ?? await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _directory = dir;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    final dir = await _dir();
    final indexFile = File('${dir.path}/$_indexFileName');
    if (!await indexFile.exists()) return;

    try {
      final decoded = jsonDecode(await indexFile.readAsString());
      if (decoded is! List) return;
      final restored = <String, OnlineCacheEntry>{};
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic>) continue;
        final entry = OnlineCacheEntry.fromJson(raw);
        if (entry == null) continue;
        // Drop entries whose file disappeared outside the app (a cleaner, a
        // manual delete); keeping them would make playback fail later.
        if (!await File('${dir.path}/${entry.fileName}').exists()) continue;
        restored[entry.songId] = entry;
      }
      _index = restored;
    } catch (e) {
      debugPrint('[OnlineCache] index unreadable, starting empty: $e');
      _index = {};
    }
  }

  Future<void> _saveIndex() async {
    final dir = await _dir();
    final indexFile = File('${dir.path}/$_indexFileName');
    await indexFile.writeAsString(
      jsonEncode([for (final entry in _index.values) entry.toJson()]),
      flush: true,
    );
  }

  /// True when [song] is a stream that could be cached at all.
  static bool isCacheable(Song song) {
    final path = song.filePath;
    if (path == null || path.isEmpty) return false;
    if (!song.isNetworkSource) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// The cached file for [song], or null when it is not cached.
  ///
  /// Also marks the entry as recently used, which keeps it off the eviction
  /// list.
  Future<File?> cachedFile(Song song) async {
    await _ensureLoaded();
    final entry = _index[song.id];
    if (entry == null) return null;

    final dir = await _dir();
    final file = File('${dir.path}/${entry.fileName}');
    if (!await file.exists()) {
      _index.remove(song.id);
      unawaited(_saveIndex());
      return null;
    }

    _index[song.id] = entry.copyWith(lastUsed: DateTime.now());
    return file;
  }

  /// Absolute path of the cached file, for handing to the player.
  Future<String?> cachedPath(Song song) async {
    final file = await cachedFile(song);
    return file?.path;
  }

  /// Downloads [song] if it is not cached yet. Returns the cached file.
  ///
  /// Concurrent calls for the same song share one download.
  Future<File?> ensureCached(
    Song song, {
    void Function(int received, int total)? onProgress,
  }) {
    if (!isCacheable(song)) return Future.value(null);
    final running = _inFlight[song.id];
    if (running != null) return running;

    final future = _download(song, onProgress: onProgress);
    _inFlight[song.id] = future;
    return future.whenComplete(() => _inFlight.remove(song.id));
  }

  Future<File?> _download(
    Song song, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _ensureLoaded();
    final existing = await cachedFile(song);
    if (existing != null) return existing;

    final dir = await _dir();
    final fileName = _fileNameFor(song);
    final target = File('${dir.path}/$fileName');
    // Downloaded under a .part name and renamed at the end, so a killed
    // download can never be mistaken for a complete file.
    final partial = File('${target.path}.part');

    try {
      final request = http.Request('GET', Uri.parse(song.filePath!));
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[OnlineCache] ${song.title}: HTTP ${response.statusCode}',
        );
        return null;
      }

      final total = response.contentLength ?? -1;
      var received = 0;
      final sink = partial.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();

      if (received == 0) {
      await _deleteQuietly(partial);
        return null;
      }

      if (await target.exists()) await target.delete();
      final file = await partial.rename(target.path);

      _index[song.id] = OnlineCacheEntry(
        songId: song.id,
        fileName: fileName,
        bytes: received,
        title: song.title,
        artist: song.artist,
        albumArt: song.albumArt,
        genre: song.genre,
        durationMs: song.duration.inMilliseconds,
        sourceType: song.sourceType,
        remoteId: song.remoteId,
        sourceUrl: song.filePath,
        addedAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );
      await _saveIndex();
      debugPrint(
        '[OnlineCache] cached "${song.title}" [${song.id}] '
        '(${(received / 1024 / 1024).toStringAsFixed(1)} MB)',
      );

      unawaited(evictIfNeeded());
      return file;
    } catch (e) {
      debugPrint('[OnlineCache] ${song.title} failed: $e');
      await _deleteQuietly(partial);
      return null;
    }
  }

  /// Changes the cap and immediately trims the cache to fit.
  Future<void> applyLimit(int bytes) async {
    maxBytes = bytes;
    await evictIfNeeded();
  }

  /// Removes least-recently-used entries until the cache fits [maxBytes].
  ///
  /// Does nothing when the limit is [noLimit].
  Future<void> evictIfNeeded() async {
    await _ensureLoaded();
    if (maxBytes <= noLimit) return;

    final dir = await _dir();

    var total = _index.values.fold<int>(0, (sum, e) => sum + e.bytes);
    if (total <= maxBytes) return;

    final byAge = _index.values.toList()
      ..sort((a, b) => a.lastUsed.compareTo(b.lastUsed));

    for (final entry in byAge) {
      if (total <= maxBytes) break;
      await _deleteQuietly(File('${dir.path}/${entry.fileName}'));
      _index.remove(entry.songId);
      total -= entry.bytes;
      debugPrint('[OnlineCache] evicted "${entry.title}"');
    }
    await _saveIndex();
  }

  /// Everything currently cached, newest first.
  Future<List<OnlineCacheEntry>> entries() async {
    await _ensureLoaded();
    final list = _index.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  /// The cached songs, ready for the player and the Downloads list.
  Future<List<Song>> cachedSongs() async {
    final dir = await _dir();
    final list = <Song>[];
    for (final entry in await entries()) {
      list.add(entry.toSong('${dir.path}/${entry.fileName}'));
    }
    return list;
  }

  Future<bool> isCached(Song song) async {
    await _ensureLoaded();
    return _index.containsKey(song.id);
  }

  Future<int> totalBytes() async {
    await _ensureLoaded();
    return _index.values.fold<int>(0, (sum, e) => sum + e.bytes);
  }

  Future<int> count() async {
    await _ensureLoaded();
    return _index.length;
  }

  /// Drops one cached track.
  Future<void> remove(Song song) async {
    await _ensureLoaded();
    final entry = _index.remove(song.id);
    if (entry == null) return;
    final dir = await _dir();
    await _deleteQuietly(File('${dir.path}/${entry.fileName}'));
    await _saveIndex();
  }

  /// Empties the cache, including any orphaned `.part` files.
  Future<void> clear() async {
    await _ensureLoaded();
    final dir = await _dir();
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          await _deleteQuietly(entity);
        }
      }
    }
    _index = {};
    await _saveIndex();
  }

  /// A filesystem-safe, collision-free name for a track.
  static String _fileNameFor(Song song) {
    final safe = song.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$safe.mp3';
  }

  /// Deletes a file, ignoring the case where it is already gone.
  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[OnlineCache] could not delete ${file.path}: $e');
    }
  }
}
