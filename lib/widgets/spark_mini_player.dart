import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/common/cached_image_widget.dart';

/// The floating mini player from the reference design.
///
/// A dark pill that hovers above the nav bar: artwork, title/artist, transport
/// controls, and a hairline progress bar along its bottom edge. It renders
/// nothing at all until a track is loaded, so the shell can always include it.
class SparkMiniPlayer extends ConsumerWidget {
  const SparkMiniPlayer({super.key, required this.onTap});

  /// Opens the Now Playing screen. Owned by the caller so the shell can animate
  /// the transition.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(isPlayingProvider);
    final progress = ref.watch(progressProvider).clamp(0.0, 1.0);
    final notifier = ref.read(playerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        0,
        SparkSpacing.page,
        10,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SparkRadius.pill),
          child: Ink(
            decoration: BoxDecoration(
              color: SparkColors.surface,
              borderRadius: BorderRadius.circular(SparkRadius.pill),
              border: Border.all(color: SparkColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.pill),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        _Artwork(
                          albumArt: song.albumArt,
                          filePath: song.filePath,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: SparkColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SparkColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: notifier.togglePlayPause,
                          icon: Icon(
                            isPlaying ? LucideIcons.pause : LucideIcons.play,
                            size: 22,
                          ),
                          color: SparkColors.textPrimary,
                        ),
                        IconButton(
                          onPressed: notifier.next,
                          icon: const Icon(LucideIcons.skipForward, size: 22),
                          color: SparkColors.textPrimary,
                        ),
                        const SizedBox(width: 2),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(height: 2, color: SparkColors.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.albumArt, this.filePath});

  final String? albumArt;
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 44,
        height: 44,
        child: albumArt != null
            ? CachedImageWidget(
                imagePath: albumArt!,
                audioSourcePath: filePath,
                fit: BoxFit.cover,
                useThumbnail: true,
                thumbnailWidth: 128,
                thumbnailHeight: 128,
              )
            : const _ArtworkPlaceholder(),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SparkColors.surfaceHigh,
      child: Icon(LucideIcons.music, size: 20, color: SparkColors.textTertiary),
    );
  }
}

/// Album artwork sized for list rows, shared by the library and home screens.
class SparkArtwork extends StatelessWidget {
  const SparkArtwork({
    super.key,
    this.albumArt,
    this.filePath,
    this.size = 56,
    this.radius = 14,
  });

  final String? albumArt;
  final String? filePath;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: albumArt != null
            ? CachedImageWidget(
                imagePath: albumArt!,
                audioSourcePath: filePath,
                fit: BoxFit.cover,
                useThumbnail: true,
                thumbnailWidth: 256,
                thumbnailHeight: 256,
              )
            : const _ArtworkPlaceholder(),
      ),
    );
  }
}
