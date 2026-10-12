import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/data/repositories/song_repository.dart';
import 'package:spark/features/home/home_screen.dart' show SparkChip;
import 'package:spark/features/library/add_music_folder.dart';
import 'package:spark/features/library/add_to_playlist.dart';
import 'package:spark/features/library/album_detail_screen.dart';
import 'package:spark/features/library/downloads_pane.dart';
import 'package:spark/features/library/playlist_detail_screen.dart';
import 'package:spark/models/playlist.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/selectable_song_list.dart';
import 'package:spark/widgets/spark_mini_player.dart';
import 'package:spark/widgets/swipe_actions.dart';

/// Library tab: the user's own music, grouped by album, with playlists and
/// liked songs behind filter chips.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Shared, so the home header's heart can open Library already on Liked.
    final filter = ref.watch(libraryFilterProvider);
    final filters = [
      l10n.chipAll,
      l10n.playlists,
      l10n.likedSongs,
      l10n.downloads,
    ];

    return Scaffold(
      backgroundColor: SparkColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: l10n.myMusic,
              onMore: () => _showLibraryMenu(context, ref),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpacing.page,
              ),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => SparkChip(
                    label: filters[i],
                    selected: i == filter,
                    onTap: () =>
                        ref.read(libraryFilterProvider.notifier).setFilter(i),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              // Each pane resolves its own data. The album pane cannot read
              // SongsState.albumGroups: that list is only populated when the
              // sort option is exactly `album`, so it is empty by default and
              // the library looked empty with songs present in the database.
              child: switch (filter) {
                1 => const _PlaylistsPane(),
                2 => const _LikedPane(),
                3 => const DownloadsPane(),
                _ => const _AlbumsPane(),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Overflow menu for the Library tab.
  ///
  /// Rescan is the action that actually matters here: the OS never tells the app
  /// that files appeared after a folder was added, so without this the library
  /// silently misses anything copied in later.
  Future<void> _showLibraryMenu(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final scanRequested = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SparkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SparkColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                LucideIcons.refreshCw,
                color: SparkColors.textSecondary,
              ),
              title: Text(
                l10n.rescanLibrary,
                style: TextStyle(color: SparkColors.textPrimary),
              ),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (scanRequested == true && context.mounted) {
      await rescanLibrary(context, ref);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onMore});

  final String title;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        12,
        SparkSpacing.page,
        16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: SparkColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onMore,
            icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
            color: SparkColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _AlbumsPane extends ConsumerWidget {
  const _AlbumsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(songsByAlbumProvider);

    return albumsAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: SparkColors.accent)),
      error: (error, _) => _Centered(
        icon: LucideIcons.circleAlert,
        title: context.l10n.libraryEmptyTitle,
        body: '$error',
      ),
      data: (albums) {
        if (albums.isEmpty) {
          return _Centered(
            icon: LucideIcons.music,
            title: context.l10n.libraryEmptyTitle,
            body: context.l10n.libraryEmptyBody,
            action: const AddMusicFolderButton(),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 140),
          itemCount: albums.length,
          itemBuilder: (context, i) {
            final album = albums[i];
            return _AlbumTile(
              album: album,
              onPlay: () => ref
                  .read(playerProvider.notifier)
                  .play(album.songs.first, playlist: album.songs),
            );
          },
        );
      },
    );
  }
}

class _PlaylistsPane extends ConsumerWidget {
  const _PlaylistsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return playlists.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: SparkColors.accent)),
      error: (error, _) => _Centered(
        icon: LucideIcons.circleAlert,
        title: context.l10n.playlists,
        body: '$error',
      ),
      data: (state) {
        final items = state.playlists;
        final l10n = context.l10n;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 140),
          // One extra row at the top is the create action; the empty state is
          // just this list with nothing under it.
          itemCount: items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Row(
                artwork: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: SparkColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(SparkRadius.card),
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    color: SparkColors.accent,
                    size: 24,
                  ),
                ),
                title: l10n.playlistNew,
                // The hint is the useful thing to say while there is nothing
                // here; once playlists exist the row reports how many, rather
                // than reusing the song count (which counts playlists).
                subtitle: items.isEmpty
                    ? l10n.playlistEmptyBody
                    : l10n.playlistCountShort(items.length),
                onPlay: () => _createPlaylist(context, ref),
              );
            }
            return _PlaylistTile(playlist: items[i - 1]);
          },
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final name = await promptPlaylistName(context);
    if (name == null || name.trim().isEmpty) return;
    final created = await ref
        .read(playlistsProvider.notifier)
        .createPlaylist(name);
    if (created == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailScreen(playlistId: created.id),
      ),
    );
  }
}

class _LikedPane extends ConsumerWidget {
  const _LikedPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoritesProvider);

    return favorites.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: SparkColors.accent)),
      error: (error, _) => _Centered(
        icon: LucideIcons.circleAlert,
        title: l10n.likedSongs,
        body: '$error',
      ),
      data: (state) {
        final songs = state.favoriteSongs;
        return SelectableSongList(
          songs: songs,
          // Not libraryEmptyBody: this pane is empty because nothing has been
          // liked yet, not because no music folder has been added.
          emptyState: _Centered(
            icon: LucideIcons.heart,
            title: l10n.likedSongs,
            body: l10n.likedEmptyBody,
          ),
          onPlay: (song, queue) =>
              ref.read(playerProvider.notifier).play(song, playlist: queue),
          swipeActionsFor: (song) => [
            // Icon-only: the heart-minus and list-plus glyphs are unambiguous
            // here, and captions crowded the row.
            SwipeAction(
              icon: LucideIcons.heartMinus,
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).removeFavorite(song.id),
            ),
            SwipeAction(
              icon: LucideIcons.listPlus,
              color: SparkColors.textSecondary,
              onPressed: () => showAddToPlaylistSheet(context, ref, song),
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
              icon: LucideIcons.heartMinus,
              label: l10n.unfavorite,
              destructive: true,
              onPressed: (picked) => ref
                  .read(favoritesProvider.notifier)
                  .removeFavorites([for (final song in picked) song.id]),
            ),
          ],
        );
      },
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.onPlay});

  final AlbumGroup album;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return _Row(
      artwork: SparkArtwork(
        albumArt: album.songs.first.albumArt,
        filePath: album.songs.first.filePath,
      ),
      title: album.albumName,
      subtitle:
          '${album.albumArtist} · ${context.l10n.songCountShort(album.songs.length)}',
      onPlay: onPlay,
      // Tapping the row opens the track list; the play button still plays the
      // whole album.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AlbumDetailScreen(album: album),
        ),
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  const _PlaylistTile({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwipeActions(
      actions: [
        SwipeAction(
          icon: LucideIcons.trash2,
          color: const Color(0xFFB3261E),
          onPressed: () => _confirmDelete(context, ref),
        ),
      ],
      child: _Row(
        artwork: const SparkArtwork(size: 56),
        title: playlist.name,
        subtitle: context.l10n.songCountShort(playlist.songIds.length),
        onPlay: () => _play(ref),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
          ),
        ),
      ),
    );
  }

  /// Deleting a playlist is destructive and cannot be undone, so the swipe
  /// reveals the action but does not commit it.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SparkColors.surface,
        title: Text(
          l10n.playlistDelete,
          style: TextStyle(color: SparkColors.textPrimary),
        ),
        content: Text(
          l10n.playlistDeleteConfirm(playlist.name),
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
    if (confirmed != true) return;
    await ref.read(playlistsProvider.notifier).deletePlaylist(playlist.id);
  }

  void _play(WidgetRef ref) {
    if (playlist.songIds.isEmpty) return;
    final library = ref.read(songsProvider).value;
    if (library == null) return;
    final byId = {for (final song in library.songs) song.id: song};
    // Keep the playlist's own order and drop ids no longer in the library.
    final songs = [
      for (final id in playlist.songIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (songs.isEmpty) return;
    ref.read(playerProvider.notifier).play(songs.first, playlist: songs);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.onPlay,
    this.onTap,
  });

  final Widget artwork;
  final String title;
  final String subtitle;
  final VoidCallback onPlay;

  /// Defaults to [onPlay]; rows that open a detail screen pass their own.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SparkSpacing.page),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? onPlay,
          borderRadius: BorderRadius.circular(SparkRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                artwork,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SparkColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: SparkColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onPlay,
                  icon: const Icon(LucideIcons.play, size: 20),
                  color: SparkColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Optional call to action under the copy. Only the empty library passes one.
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
