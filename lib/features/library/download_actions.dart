import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';

/// Saves [songs] for offline use and reports the outcome.
///
/// Shared by the download button and the swipe / multi-select actions so all
/// three behave identically: into the user's music folder when one has been
/// granted, otherwise into the private cache.
Future<void> saveSongsOffline(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
) async {
  if (songs.isEmpty) return;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);

  final folders = await ref.read(musicFoldersProvider.future);
  final treeUri = folders.isEmpty ? null : folders.first.uri;

  final saved = await ref
      .read(downloadsProvider.notifier)
      .saveAll(songs, treeUri);

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        saved == 0
            ? l10n.downloadFailed
            : treeUri == null
            ? l10n.downloadCachedOnly
            : l10n.downloaded,
      ),
    ),
  );
}

/// Drops [songs] from the offline cache.
Future<void> removeDownloads(WidgetRef ref, List<Song> songs) async {
  if (songs.isEmpty) return;
  await ref.read(downloadsProvider.notifier).removeAll(songs);
}
