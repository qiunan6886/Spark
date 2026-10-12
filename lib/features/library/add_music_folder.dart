import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/core/utils/dev_log.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/services/music_folder_service.dart';

/// Runs the whole add-a-folder flow and starts the scan.
///
/// [MusicFolderService.addFolder] already owns the picker, the persistable
/// permission and persistence; this only has to report the outcome and kick off
/// the scan, so both empty states and the settings row share one implementation.
///
/// Returns true when a folder was actually added.
Future<bool> runAddMusicFolder(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);

  try {
    final folder = await MusicFolderService().addFolder();
    // null means the user dismissed the system picker: not an error, say nothing.
    if (folder == null) return false;

    ref.invalidate(musicFoldersProvider);
    unawaited(
      ref
          .read(libraryScannerProvider.notifier)
          .scanFolder(folder.uri, folder.displayName),
    );

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(l10n.folderAdded(folder.displayName))),
      );
    return true;
  } on FolderAlreadyExistsException {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.folderAlreadyAdded)));
    return false;
  } catch (e) {
    devLog('Add music folder failed: $e');
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.folderAddFailed)));
    return false;
  }
}

/// Rescans every registered folder.
///
/// Shared by the Settings row and the Library overflow menu. Needed because the
/// OS gives no way to notice files copied in after a folder was added.
Future<void> rescanLibrary(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(context.l10n.rescanStarted)));
  await ref.read(libraryScannerProvider.notifier).scanAllFolders();
}

/// The primary call to action on an empty library: a solid lime pill that opens
/// the system folder picker. Shows a spinner while the picker and the initial
/// scan are in flight.
class AddMusicFolderButton extends ConsumerStatefulWidget {
  const AddMusicFolderButton({super.key});

  @override
  ConsumerState<AddMusicFolderButton> createState() =>
      _AddMusicFolderButtonState();
}

class _AddMusicFolderButtonState extends ConsumerState<AddMusicFolderButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await runAddMusicFolder(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _onPressed,
      icon: _busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SparkColors.onAccent,
              ),
            )
          : const Icon(LucideIcons.folderPlus, size: 18),
      label: Text(
        _busy ? context.l10n.libraryScanning : context.l10n.libraryAddFolder,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: SparkColors.accent,
        foregroundColor: SparkColors.onAccent,
        disabledBackgroundColor: SparkColors.accent.withValues(alpha: 0.5),
        disabledForegroundColor: SparkColors.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkRadius.pill),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
