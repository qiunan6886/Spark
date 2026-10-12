import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/features/library/add_to_playlist.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/online_track_row.dart';
import 'package:spark/widgets/swipe_actions.dart';

/// Converts an `onReorderItem` index back to the raw index that
/// [PlaylistService.reorderSongs] expects.
///
/// `onReorderItem` hands over an index already adjusted for the removed item,
/// while `reorderSongs` applies that same adjustment itself. Without undoing it
/// here every downward drag lands one slot short.
int rawReorderIndex(int oldIndex, int newIndex) =>
    oldIndex < newIndex ? newIndex + 1 : newIndex;

/// One playlist: its songs, in its own order, with play / reorder / remove.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playlist = ref.watch(playlistProvider(playlistId));
    final library = ref.watch(songsProvider).value;

    if (playlist == null) {
      // Either still loading or deleted from under us.
      return Scaffold(
        backgroundColor: SparkColors.background,
        appBar: AppBar(
          backgroundColor: SparkColors.background,
          foregroundColor: SparkColors.textPrimary,
        ),
        body: Center(
          child: CircularProgressIndicator(color: SparkColors.accent),
        ),
      );
    }

    final byId = {
      for (final song in library?.songs ?? const <Song>[]) song.id: song,
    };
    final songs = [
      for (final id in playlist.songIds)
        if (byId[id] != null) byId[id]!,
    ];

    // Reordering maps list positions back onto songIds, which only lines up
    // when every id resolved. Rather than shuffle the wrong entries, dragging
    // is switched off if a file has gone missing since it was added.
    final canReorder = songs.length == playlist.songIds.length;

    return Scaffold(
      backgroundColor: SparkColors.background,
      appBar: AppBar(
        backgroundColor: SparkColors.background,
        foregroundColor: SparkColors.textPrimary,
        title: Text(playlist.name),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.ellipsisVertical),
            color: SparkColors.surfaceHigh,
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  final name = await promptPlaylistName(
                    context,
                    initialValue: playlist.name,
                  );
                  if (name == null || name.trim().isEmpty) return;
                  await ref
                      .read(playlistsProvider.notifier)
                      .renamePlaylist(playlist.id, name);
                case 'delete':
                  final confirmed = await _confirmDelete(context, playlist.name);
                  if (!confirmed) return;
                  await ref
                      .read(playlistsProvider.notifier)
                      .deletePlaylist(playlist.id);
                  if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(
                  l10n.rename,
                  style: TextStyle(color: SparkColors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  l10n.delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: songs.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: SparkColors.accent,
              foregroundColor: SparkColors.background,
              onPressed: () => ref
                  .read(playerProvider.notifier)
                  .play(songs.first, playlist: songs),
              icon: const Icon(LucideIcons.play),
              label: Text(l10n.playAll),
            ),
      body: songs.isEmpty
          ? const _Empty()
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 140),
              buildDefaultDragHandles: false,
              itemCount: songs.length,
              onReorderItem: (oldIndex, newIndex) {
                if (!canReorder) return;
                ref
                    .read(playlistsProvider.notifier)
                    .reorderSongs(
                      playlist.id,
                      oldIndex,
                      rawReorderIndex(oldIndex, newIndex),
                    );
              },
              itemBuilder: (context, i) {
                final song = songs[i];
                return _PlaylistSongRow(
                  key: ValueKey('${playlist.id}:${song.id}'),
                  song: song,
                  index: i,
                  canReorder: canReorder,
                  onPlay: () => ref
                      .read(playerProvider.notifier)
                      .play(song, playlist: songs),
                  onRemove: () => ref
                      .read(playlistsProvider.notifier)
                      .removeSongFromPlaylist(playlist.id, song.id),
                );
              },
            ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context, String name) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SparkColors.surface,
        title: Text(
          l10n.playlistDelete,
          style: TextStyle(color: SparkColors.textPrimary),
        ),
        content: Text(
          l10n.playlistDeleteConfirm(name),
          style: TextStyle(color: SparkColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: SparkColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _PlaylistSongRow extends StatelessWidget {
  const _PlaylistSongRow({
    super.key,
    required this.song,
    required this.index,
    required this.canReorder,
    required this.onPlay,
    required this.onRemove,
  });

  final Song song;
  final int index;
  final bool canReorder;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = OnlineTrackRow(
      song: song,
      onTap: onPlay,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRemove,
            icon: const Icon(LucideIcons.x, size: 18),
            color: SparkColors.textTertiary,
            tooltip: l10n.removeFromPlaylist,
          ),
          if (canReorder)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  LucideIcons.gripVertical,
                  size: 20,
                  color: SparkColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );

    // Swipe is added on top of the drag handle rather than replacing it:
    // reordering is the primary action in a playlist, and the handle keeps
    // that while the swipe gives quick removal.
    return SwipeActions(
      actions: [
        SwipeAction(
          icon: LucideIcons.listX,
          label: l10n.removeFromPlaylist,
          color: const Color(0xFFB3261E),
          onPressed: onRemove,
        ),
      ],
      child: GestureDetector(
        onLongPress: onRemove,
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.listMusic,
              size: 44,
              color: SparkColors.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.playlistEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: SparkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.playlistEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: SparkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
