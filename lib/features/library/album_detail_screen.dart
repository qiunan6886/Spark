import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/data/repositories/song_repository.dart';
import 'package:spark/features/library/add_to_playlist.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/selectable_song_list.dart';
import 'package:spark/widgets/spark_mini_player.dart' show SparkArtwork;
import 'package:spark/widgets/swipe_actions.dart';

/// An album's track list.
///
/// Tapping an album used to just start playing it, so there was no way to see
/// what was on it or to play one track from the middle. The row tap now opens
/// this, and the play button still plays the whole album.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final AlbumGroup album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final songs = album.songs;

    if (songs.isEmpty) {
      return Scaffold(
        backgroundColor: SparkColors.background,
        appBar: AppBar(
          backgroundColor: SparkColors.background,
          foregroundColor: SparkColors.textPrimary,
          title: Text(album.albumName),
        ),
        body: Center(
          child: Text(
            l10n.filterEmptyBody,
            style: TextStyle(color: SparkColors.textSecondary),
          ),
        ),
      );
    }

    void playAll() =>
        ref.read(playerProvider.notifier).play(songs.first, playlist: songs);

    return Scaffold(
      backgroundColor: SparkColors.background,
      appBar: AppBar(
        backgroundColor: SparkColors.background,
        foregroundColor: SparkColors.textPrimary,
        title: Text(
          album.albumName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SparkColors.accent,
        foregroundColor: SparkColors.background,
        onPressed: playAll,
        icon: const Icon(LucideIcons.play),
        label: Text(l10n.playAll),
      ),
      body: SelectableSongList(
        songs: songs,
        header: _AlbumHeader(album: album, onPlayAll: playAll),
        onPlay: (song, queue) =>
            ref.read(playerProvider.notifier).play(song, playlist: queue),
        swipeActionsFor: (song) => [
          SwipeAction(
            icon: LucideIcons.listPlus,
            color: SparkColors.textSecondary,
            onPressed: () => showAddToPlaylistSheet(context, ref, song),
          ),
          SwipeAction(
            icon: LucideIcons.heart,
            onPressed: () => ref
                .read(favoritesProvider.notifier)
                .addFavorite(song.id, song: song),
          ),
        ],
        selectionActions: [
          SelectionAction(
            icon: LucideIcons.listPlus,
            label: l10n.addToPlaylist,
            onPressed: (picked) =>
                showAddSongsToPlaylistSheet(context, ref, picked),
          ),
          SelectionAction(
            icon: LucideIcons.heart,
            label: l10n.favorite,
            onPressed: (picked) => ref
                .read(favoritesProvider.notifier)
                .addFavorites([for (final song in picked) song.id]),
          ),
        ],
      ),
    );
  }
}

/// Cover, title and a play-all control, above the track list.
class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({required this.album, required this.onPlayAll});

  final AlbumGroup album;
  final VoidCallback onPlayAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lead = album.songs.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        4,
        SparkSpacing.page,
        14,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(SparkRadius.card),
            child: SizedBox(
              width: 96,
              height: 96,
              child: SparkArtwork(
                albumArt: lead.albumArt,
                filePath: lead.filePath,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.albumName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SparkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${album.albumArtist} · '
                  '${l10n.songCountShort(album.songs.length)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: SparkColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onPlayAll,
                  icon: const Icon(LucideIcons.play, size: 16),
                  label: Text(l10n.playAll),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SparkColors.accent,
                    side: BorderSide(
                      color: SparkColors.accent.withValues(alpha: 0.4),
                    ),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SparkRadius.pill),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
