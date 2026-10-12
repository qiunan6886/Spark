import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../services/online_cache_service.dart';
import '../services/online_download_service.dart';

final onlineCacheServiceProvider = Provider<OnlineCacheService>(
  (ref) => OnlineCacheService.instance,
);

final onlineDownloadServiceProvider = Provider<OnlineDownloadService>(
  (ref) => const OnlineDownloadService(),
);

/// The tracks held in the streaming cache, newest first.
///
/// Everything here is playable offline, so the Downloads view is the cache
/// rather than a separate list -- an auto-cached track is just as offline as an
/// explicitly downloaded one.
final downloadsProvider =
    AsyncNotifierProvider<DownloadsNotifier, List<OnlineCacheEntry>>(
      DownloadsNotifier.new,
    );

class DownloadsNotifier extends AsyncNotifier<List<OnlineCacheEntry>> {
  @override
  Future<List<OnlineCacheEntry>> build() {
    return ref.watch(onlineCacheServiceProvider).entries();
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(onlineCacheServiceProvider).entries());
  }

  /// Downloads a track into the user's music folder and refreshes the list.
  ///
  /// Returns true when the file was written. The cache is populated as a side
  /// effect, so the track also appears here immediately.
  Future<bool> downloadTo(Song song, String folderTreeUri) async {
    final uri = await ref
        .read(onlineDownloadServiceProvider)
        .downloadToFolder(song, folderTreeUri);
    await refresh();
    return uri != null;
  }

  /// Saves several tracks, returning how many succeeded.
  ///
  /// [folderTreeUri] null -- no music folder has been granted -- falls back to
  /// the private cache, which is still playable offline.
  Future<int> saveAll(List<Song> songs, String? folderTreeUri) async {
    if (songs.isEmpty) return 0;

    var saved = 0;
    for (final song in songs) {
      if (folderTreeUri != null) {
        final uri = await ref
            .read(onlineDownloadServiceProvider)
            .downloadToFolder(song, folderTreeUri);
        if (uri != null) saved++;
      } else {
        final file = await ref
            .read(onlineCacheServiceProvider)
            .ensureCached(song);
        if (file != null) saved++;
      }
    }

    await refresh();
    return saved;
  }

  /// Drops one cached track.
  Future<void> remove(Song song) async {
    await ref.read(onlineCacheServiceProvider).remove(song);
    await refresh();
  }

  /// Drops several cached tracks with a single refresh.
  Future<void> removeAll(List<Song> songs) async {
    final cache = ref.read(onlineCacheServiceProvider);
    for (final song in songs) {
      await cache.remove(song);
    }
    await refresh();
  }
}

/// The cached tracks as playable [Song]s, pointed at their files on disk.
final cachedSongsProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  // Rebuild whenever the cache index changes.
  await ref.watch(downloadsProvider.future);
  return ref.watch(onlineCacheServiceProvider).cachedSongs();
});

/// Whether one specific song is cached, for the per-row button.
final isSongCachedProvider = Provider.autoDispose.family<bool, String>((
  ref,
  songId,
) {
  final entries = ref.watch(downloadsProvider).value;
  if (entries == null) return false;
  for (final entry in entries) {
    if (entry.songId == songId) return true;
  }
  return false;
});

/// Total bytes held by the cache.
final cacheSizeProvider = Provider.autoDispose<int>((ref) {
  final entries = ref.watch(downloadsProvider).value;
  if (entries == null) return 0;
  return entries.fold<int>(0, (sum, entry) => sum + entry.bytes);
});

/// How many tracks are held.
final cacheCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(downloadsProvider).value?.length ?? 0;
});

/// The user's cache cap, persisted across launches.
final cacheLimitProvider = NotifierProvider<CacheLimitNotifier, int>(
  CacheLimitNotifier.new,
);

class CacheLimitNotifier extends Notifier<int> {
  static const _prefsKey = 'spark.online_cache_limit';

  @override
  int build() {
    _restore();
    return OnlineCacheService.kDefaultMaxBytes;
  }

  /// Applies the stored cap on startup. The service is constructed with the
  /// default, so without this a raised or lowered limit would only take effect
  /// on the next launch.
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_prefsKey);
    if (stored == null || !ref.mounted) return;

    state = stored;
    await ref.read(onlineCacheServiceProvider).applyLimit(stored);
    await ref.read(downloadsProvider.notifier).refresh();
  }

  Future<void> setLimit(int bytes) async {
    if (state == bytes) return;
    state = bytes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, bytes);

    // Lowering the cap must free the space straight away, not at the next
    // download.
    await ref.read(onlineCacheServiceProvider).applyLimit(bytes);
    await ref.read(downloadsProvider.notifier).refresh();
  }
}

/// True when the cap means "never evict".
bool isUnlimitedCache(int bytes) => bytes <= OnlineCacheService.noLimit;

/// Empties the cache. Exposed as a provider so the settings screen and any
/// future caller share one implementation.
final clearCacheProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(onlineCacheServiceProvider).clear();
    await ref.read(downloadsProvider.notifier).refresh();
    ref.invalidate(cachedSongsProvider);
  };
});
