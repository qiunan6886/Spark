import 'package:flutter/material.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/models/song.dart';
import 'package:spark/widgets/spark_mini_player.dart' show SparkArtwork;

/// A horizontally scrolling strip of cover cards.
///
/// Used for "Recently played" on Home, where a short row of large covers is the
/// familiar shape and keeps the vertical list free for albums.
class RecentStrip extends StatelessWidget {
  const RecentStrip({
    super.key,
    required this.title,
    required this.songs,
    required this.onPlay,
  });

  final String title;
  final List<Song> songs;
  final void Function(int index) onPlay;

  static const double _cardSize = 116;
  static const double _stripHeight = 172;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SparkSpacing.page,
            0,
            SparkSpacing.page,
            12,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: SparkColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: _stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: SparkSpacing.page),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _RecentCard(
              song: songs[i],
              size: _cardSize,
              onTap: () => onPlay(i),
            ),
          ),
        ),
        const SizedBox(height: SparkSpacing.section),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.song,
    required this.size,
    required this.onTap,
  });

  final Song song;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.card),
              child: SizedBox(
                width: size,
                height: size,
                child: SparkArtwork(
                  albumArt: song.albumArt,
                  filePath: song.filePath,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SparkColors.textPrimary,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: SparkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
