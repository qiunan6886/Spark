import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';

/// Saves a streamed track for offline listening.
///
/// A track is cached automatically the first time it plays, so this button is
/// for the deliberate case: getting the file into the user's own music folder,
/// where it shows up like any other local track.
class SongDownloadButton extends ConsumerStatefulWidget {
  const SongDownloadButton({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<SongDownloadButton> createState() => _SongDownloadButtonState();
}

class _SongDownloadButtonState extends ConsumerState<SongDownloadButton> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cached = ref.watch(isSongCachedProvider(widget.song.id));

    if (_working) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SparkColors.accent,
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: cached ? l10n.downloaded : l10n.download,
      onPressed: () => _save(context),
      icon: Icon(
        cached ? LucideIcons.circleCheck : LucideIcons.download,
        size: 20,
      ),
      color: cached ? SparkColors.accent : SparkColors.textSecondary,
    );
  }

  Future<void> _save(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);

    final folders = await ref.read(musicFoldersProvider.future);
    final treeUri = folders.isEmpty ? null : folders.first.uri;

    final String message;
    if (treeUri != null) {
      final saved = await ref
          .read(downloadsProvider.notifier)
          .downloadTo(widget.song, treeUri);
      message = saved ? l10n.downloaded : l10n.downloadFailed;
    } else {
      // No music folder has been granted, so the best available outcome is the
      // private cache: still playable offline, just not visible to other apps.
      final file = await ref
          .read(onlineCacheServiceProvider)
          .ensureCached(widget.song);
      await ref.read(downloadsProvider.notifier).refresh();
      message = file == null ? l10n.downloadFailed : l10n.downloadCachedOnly;
    }

    if (!mounted) return;
    setState(() => _working = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
