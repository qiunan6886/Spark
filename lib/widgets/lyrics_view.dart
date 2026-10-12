import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/theme/spark_theme.dart';
import '../core/l10n/l10n_context.dart';
import '../models/song.dart';
import '../providers/providers.dart';

/// Synced lyrics for the now-playing screen.
///
/// Resolves lyrics through [songLyricsProvider], which downloads from lrclib.net
/// and caches beside the song the first time a track is viewed. The current line
/// is highlighted and kept centred while playback advances.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  /// Fixed row height makes "scroll line N to the middle" plain arithmetic --
  /// no per-row key measurement, which would need a second layout pass.
  static const double _lineExtent = 46;

  final ScrollController _scrollController = ScrollController();
  int _lastCentredIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Centres [index] in the viewport, clamped to the scrollable range.
  void _centreLine(int index) {
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final target = index * _lineExtent - viewport / 2 + _lineExtent / 2;
    final clamped = target.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(songLyricsProvider(widget.song));

    return lyricsAsync.when(
      loading: () => _LyricsStatus(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: SparkColors.accent,
          ),
        ),
      ),
      error: (error, _) => _LyricsStatus(
        child: _LyricsMessage(
          icon: LucideIcons.circleAlert,
          text: context.l10n.lyricsUnavailable,
        ),
      ),
      data: (data) {
        if (data == null || data.lines.isEmpty) {
          return _LyricsStatus(
            child: _LyricsMessage(
              icon: LucideIcons.music,
              text: context.l10n.lyricsUnavailable,
            ),
          );
        }

        final position = ref.watch(positionProvider);
        final activeIndex = data.isSynchronized
            ? ref
                  .read(lyricsServiceProvider)
                  .findCurrentLineIndex(data, position)
            : -1;

        if (activeIndex != _lastCentredIndex && activeIndex >= 0) {
          _lastCentredIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centreLine(activeIndex);
          });
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 120),
          itemExtent: _lineExtent,
          itemCount: data.lines.length,
          itemBuilder: (context, i) => _LyricLineRow(
            text: data.lines[i].text,
            active: i == activeIndex,
          ),
        );
      },
    );
  }
}

class _LyricLineRow extends StatelessWidget {
  const _LyricLineRow({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      style: TextStyle(
        fontSize: active ? 19 : 16,
        height: 1.3,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        color: active ? SparkColors.accent : SparkColors.textTertiary,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _LyricsStatus extends StatelessWidget {
  const _LyricsStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 34, color: SparkColors.textTertiary),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: SparkColors.textSecondary),
        ),
      ],
    );
  }
}
