import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/features/library/add_to_playlist.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/selectable_song_list.dart';
import 'package:spark/widgets/swipe_actions.dart';

/// Streamed tracks held on disk, so they play offline.
///
/// This is the streaming cache rather than a separate download list: a track
/// kept automatically the first time it played is just as playable offline as
/// one saved on purpose, and splitting them would only confuse.
class DownloadsPane extends ConsumerWidget {
  const DownloadsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final songs = ref.watch(cachedSongsProvider);
    final usedBytes = ref.watch(cacheSizeProvider);

    return songs.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: SparkColors.accent)),
      error: (error, _) => CenteredPaneMessage(
        icon: LucideIcons.circleAlert,
        title: l10n.downloads,
        body: '$error',
      ),
      data: (list) {
        return SelectableSongList(
          songs: list,
          emptyState: CenteredPaneMessage(
            icon: LucideIcons.download,
            title: l10n.downloadsEmptyTitle,
            body: l10n.downloadsEmptyBody,
          ),
          header: list.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SparkSpacing.page,
                    4,
                    SparkSpacing.page,
                    8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.cacheUsage(formatBytes(usedBytes)),
                        style: TextStyle(
                          fontSize: 12,
                          color: SparkColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            ref.read(downloadsProvider.notifier).refresh(),
                        child: Text(
                          l10n.refresh,
                          style: TextStyle(
                            fontSize: 12,
                            color: SparkColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          onPlay: (song, queue) =>
              ref.read(playerProvider.notifier).play(song, playlist: queue),
          // Icon-only actions, matching the other library rows. Filing a
          // download into a playlist is the useful second action here.
          swipeActionsFor: (song) => [
            SwipeAction(
              icon: LucideIcons.listPlus,
              color: SparkColors.textSecondary,
              onPressed: () => showAddToPlaylistSheet(context, ref, song),
            ),
            SwipeAction(
              icon: LucideIcons.trash2,
              color: const Color(0xFFB3261E),
              onPressed: () =>
                  ref.read(downloadsProvider.notifier).remove(song),
            ),
          ],
          selectionActions: [
            SelectionAction(
              icon: LucideIcons.trash2,
              label: l10n.removeDownload,
              destructive: true,
              onPressed: (picked) async {
                final notifier = ref.read(downloadsProvider.notifier);
                for (final song in picked) {
                  await notifier.remove(song);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// Centred icon + copy, used for a pane that has nothing to show.
class CenteredPaneMessage extends StatelessWidget {
  const CenteredPaneMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: SparkColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: SparkColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: SparkColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}

/// `512 KB`, `8.0 MB`, `2.00 GB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
