import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/models/song.dart';
import 'package:spark/widgets/spark_mini_player.dart' show SparkArtwork;

/// One track row, used by every song list in the app.
///
/// [trailing] replaces the play glyph, which is how the download button and the
/// playlist remove button are attached without a second row layout. [selected]
/// swaps the artwork for a checkmark while a list is in multi-select mode.
class OnlineTrackRow extends StatelessWidget {
  const OnlineTrackRow({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.selected = false,
    this.showSelectionMark = false,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  /// Draws the row as picked.
  final bool selected;

  /// Draws a checkmark box instead of the artwork, so a list in selection mode
  /// reads as a checklist.
  final bool showSelectionMark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected
            ? SparkColors.accent.withValues(alpha: 0.10)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpacing.page,
          vertical: 8,
        ),
        child: Row(
          children: [
            if (showSelectionMark) ...[
              Icon(
                selected
                    ? LucideIcons.circleCheck
                    : LucideIcons.circle,
                size: 24,
                color: selected
                    ? SparkColors.accent
                    : SparkColors.textTertiary,
              ),
              const SizedBox(width: 14),
            ] else
              SparkArtwork(albumArt: song.albumArt, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
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
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: SparkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatTrackDuration(song.duration),
              style: TextStyle(fontSize: 12, color: SparkColors.textTertiary),
            ),
            const SizedBox(width: 10),
            if (!showSelectionMark)
              trailing ??
                  Icon(
                    LucideIcons.play,
                    size: 20,
                    color: SparkColors.textSecondary,
                  ),
          ],
        ),
      ),
    );
  }
}

/// `m:ss`, used for streaming rows where the length is already known.
String formatTrackDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
