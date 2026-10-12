import 'package:flutter/services.dart';
import 'package:spark/models/song.dart';
import 'package:spark/services/online_cache_service.dart';

/// Saves a streamed track into the user's own music folder.
///
/// Two steps: get the bytes (the cache already knows how) and hand the file to
/// Android to copy into a SAF tree the user has granted. The copy happens in
/// Kotlin so multi-megabyte audio never crosses the method channel.
class OnlineDownloadService {
  const OnlineDownloadService();

  static const MethodChannel _storage = MethodChannel(
    'com.mossapps.spark/storage',
  );

  /// Caches [song] if needed, then copies it into [folderTreeUri].
  ///
  /// Returns the new document URI, or null if either step failed.
  Future<String?> downloadToFolder(
    Song song,
    String folderTreeUri, {
    void Function(int received, int total)? onProgress,
  }) async {
    final file = await OnlineCacheService.instance.ensureCached(
      song,
      onProgress: onProgress,
    );
    if (file == null) return null;

    try {
      return await _storage.invokeMethod<String>('copyFileToTree', {
        'treeUri': folderTreeUri,
        'sourcePath': file.path,
        'fileName': fileNameFor(song),
        'mimeType': 'audio/mpeg',
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Non-Android target; nothing to copy into.
      return null;
    }
  }

  /// A human-readable file name, as it will appear in the user's folder.
  static String fileNameFor(Song song) {
    final artist = song.artist.trim();
    final title = song.title.trim();
    final stem = artist.isEmpty || artist == 'Unknown Artist'
        ? title
        : '$artist - $title';
    // Strip the characters Android's document providers reject.
    final safe = stem.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    final trimmed = safe.length > 120 ? safe.substring(0, 120) : safe;
    return '${trimmed.isEmpty ? 'track' : trimmed}.mp3';
  }
}
