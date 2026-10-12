import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';

/// Asks for a playlist name. Returns null if cancelled.
Future<String?> promptPlaylistName(
  BuildContext context, {
  String? initialValue,
}) {
  final l10n = context.l10n;
  final controller = TextEditingController(text: initialValue);
  final isRename = initialValue != null;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: SparkColors.surface,
      title: Text(
        isRename ? l10n.playlistRename : l10n.playlistNew,
        style: TextStyle(color: SparkColors.textPrimary),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: SparkColors.textPrimary),
        decoration: InputDecoration(
          hintText: l10n.playlistNameHint,
          hintStyle: TextStyle(color: SparkColors.textTertiary),
        ),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            l10n.cancel,
            style: TextStyle(color: SparkColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(
            isRename ? l10n.rename : l10n.create,
            style: TextStyle(color: SparkColors.accent),
          ),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Bottom sheet listing the playlists, so [song] can be filed into one.
///
/// Tapping a playlist that already holds the song removes it, which makes the
/// sheet a toggle rather than a one-way action.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Song song,
) => showAddSongsToPlaylistSheet(context, ref, [song]);

/// Multi-select variant: files every song in [songs] into the chosen playlist.
///
/// The toggle behaviour is kept only for the single-song case, since removing
/// several tracks by tapping a playlist once would be a surprising way to
/// delete things.
Future<void> showAddSongsToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
) async {
  if (songs.isEmpty) return;
  final l10n = context.l10n;
  final single = songs.length == 1 ? songs.first : null;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: SparkColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SparkRadius.hero),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (context, sheetRef, _) {
          final playlists = sheetRef.watch(playlistsProvider);

          return playlists.when(
            loading: () => SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: SparkColors.accent),
              ),
            ),
            error: (error, _) => SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  '$error',
                  style: TextStyle(color: SparkColors.textSecondary),
                ),
              ),
            ),
            data: (state) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Text(
                    l10n.addToPlaylist,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: SparkColors.textPrimary,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    LucideIcons.plus,
                    color: SparkColors.accent,
                  ),
                  title: Text(
                    l10n.playlistNew,
                    style: TextStyle(
                      color: SparkColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    final name = await promptPlaylistName(sheetContext);
                    if (name == null || name.trim().isEmpty) return;
                    final created = await sheetRef
                        .read(playlistsProvider.notifier)
                        .createPlaylist(name);
                    if (created == null) return;
                    // One save for the whole selection.
                    await sheetRef
                        .read(playlistsProvider.notifier)
                        .addSongsToPlaylist(created.id, [
                          for (final song in songs) song.id,
                        ]);
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                ),
                if (state.playlists.isNotEmpty)
                  Divider(height: 1, color: SparkColors.border),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.playlists.length,
                    itemBuilder: (context, i) {
                      final playlist = state.playlists[i];
                      final contains = single != null &&
                          playlist.songIds.contains(single.id);
                      return ListTile(
                        leading: Icon(
                          LucideIcons.listMusic,
                          color: SparkColors.textSecondary,
                        ),
                        title: Text(
                          playlist.name,
                          style: TextStyle(color: SparkColors.textPrimary),
                        ),
                        subtitle: Text(
                          l10n.songCountShort(playlist.songIds.length),
                          style: TextStyle(
                            color: SparkColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: contains
                            ? Icon(
                                LucideIcons.check,
                                color: SparkColors.accent,
                                size: 20,
                              )
                            : null,
                        onTap: () async {
                          final notifier = sheetRef.read(
                            playlistsProvider.notifier,
                          );
                          // `contains` already implies a single-song sheet.
                          if (contains) {
                            await notifier.removeSongFromPlaylist(
                              playlist.id,
                              single.id,
                            );
                          } else {
                            // The `song` argument is deliberately omitted: it
                            // makes the notifier also push the track onto the
                            // playback queue, which is not what "add to a
                            // playlist" should do.
                            await notifier.addSongsToPlaylist(playlist.id, [
                              for (final song in songs) song.id,
                            ]);
                          }
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  contains
                                      ? l10n.removeFromPlaylist
                                      : l10n.addedToPlaylist(playlist.name),
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ),
  );
}
