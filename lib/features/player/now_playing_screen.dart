import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/common/cached_image_widget.dart';
import 'package:spark/widgets/lyrics_view.dart';
import 'package:spark/widgets/spark_heart.dart';

/// Full-screen player, matching the reference design: circular artwork, title
/// and artist, a scrub bar, and a transport row under a large lime play button.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  /// Non-null while the user is dragging the scrub bar, so the incoming
  /// position stream does not fight the finger.
  double? _scrubValue;

  /// Swaps the circular artwork for synced lyrics.
  bool _showLyrics = false;

  /// Pixels per second a cover swipe must reach to change track. High enough
  /// that a slow nudge while looking at the artwork does nothing.
  static const double _swipeVelocityThreshold = 250;

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider);

    if (song == null) {
      return Scaffold(
        backgroundColor: SparkColors.background,
        appBar: AppBar(),
        body: Center(
          child: Text(
            '—',
            style: TextStyle(color: SparkColors.textSecondary),
          ),
        ),
      );
    }

    final isPlaying = ref.watch(isPlayingProvider);
    final duration = ref.watch(durationProvider);
    final livePosition = ref.watch(positionProvider);
    final isShuffle = ref.watch(isShuffleProvider);
    final isFavorite = ref.watch(isSongFavoriteProvider(song.id));
    final notifier = ref.read(playerProvider.notifier);

    final total = duration.inMilliseconds.toDouble();
    final positionMs = _scrubValue ?? livePosition.inMilliseconds.toDouble();
    final maxValue = total <= 0 ? 1.0 : total;
    final sliderValue = positionMs.clamp(0.0, maxValue);

    return Scaffold(
      backgroundColor: SparkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: context.l10n.nowPlaying,
              isFavorite: isFavorite,
              showLyrics: _showLyrics,
              onToggleLyrics: () =>
                  setState(() => _showLyrics = !_showLyrics),
              // The song is passed along so a streamed track's details are
              // stored with the favourite; without them it could be favourited
              // but never listed in Liked.
              onFavorite: () => ref
                  .read(favoritesProvider.notifier)
                  .toggleFavorite(song.id, song: song),
              onSleepTimer: () => _showSleepTimer(context, ref),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpacing.page,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // The centre stage is shared: rotating artwork by default,
                    // synced lyrics when toggled from the top bar.
                    Expanded(
                      child: _showLyrics
                          ? LyricsView(song: song)
                          : Center(
                              // Swiping the cover changes track. Scoped to the
                              // artwork rather than the whole screen on purpose:
                              // the progress bar below is a horizontal-drag
                              // control, and a page-wide recogniser would fight
                              // it for the gesture.
                              child: GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  final velocity =
                                      details.primaryVelocity ?? 0;
                                  if (velocity.abs() < _swipeVelocityThreshold) {
                                    return;
                                  }
                                  final notifier =
                                      ref.read(playerProvider.notifier);
                                  // Dragging leftwards (negative velocity) moves
                                  // forward, matching every cover-flow UI.
                                  if (velocity < 0) {
                                    notifier.next();
                                  } else {
                                    notifier.previous();
                                  }
                                },
                                child: _Artwork(
                                  albumArt: song.albumArt,
                                  filePath: song.filePath,
                                  isPlaying: isPlaying,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: SparkColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.artist,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: SparkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 26),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: SparkColors.accent,
                        inactiveTrackColor: SparkColors.border,
                        thumbColor: SparkColors.accent,
                        overlayColor: SparkColors.accent.withValues(alpha: 0.15),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: sliderValue,
                        max: maxValue,
                        onChanged: (value) =>
                            setState(() => _scrubValue = value),
                        onChangeEnd: (value) {
                          setState(() => _scrubValue = null);
                          notifier.seek(
                            Duration(milliseconds: value.round()),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _format(Duration(milliseconds: positionMs.round())),
                            style: TextStyle(
                              fontSize: 12,
                              color: SparkColors.textSecondary,
                            ),
                          ),
                          Text(
                            _format(duration),
                            style: TextStyle(
                              fontSize: 12,
                              color: SparkColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _Controls(
                      isPlaying: isPlaying,
                      isShuffle: isShuffle,
                      onShuffle: notifier.toggleShuffle,
                      onPrevious: notifier.previous,
                      onToggle: notifier.togglePlayPause,
                      onNext: notifier.next,
                      onQueue: () => _showQueue(context, ref),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Shows the play queue, highlighting the current track. Tapping a row jumps
  /// to it.
  /// Sleep-timer picker.
  ///
  /// A sheet rather than a menu because the presets are the whole decision --
  /// there is nothing to configure beyond picking one.
  void _showSleepTimer(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SparkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.hero),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                l10n.sleepTimer,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: SparkColors.textPrimary,
                ),
              ),
            ),
            for (final preset in SleepTimerNotifier.presets)
              ListTile(
                leading: Icon(
                  LucideIcons.moon,
                  color: SparkColors.textSecondary,
                ),
                title: Text(
                  l10n.sleepTimerMinutes(preset.inMinutes),
                  style: TextStyle(color: SparkColors.textPrimary),
                ),
                onTap: () {
                  ref.read(sleepTimerProvider.notifier).start(preset);
                  Navigator.pop(sheetContext);
                },
              ),
            if (ref.read(sleepTimerProvider) != null)
              ListTile(
                leading: Icon(
                  LucideIcons.x,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.sleepTimerOff,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  ref.read(sleepTimerProvider.notifier).cancel();
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showQueue(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queue = ref.read(playbackQueueProvider);
    if (queue.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SparkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          // Watched inside the sheet so a track change while it is open keeps
          // the highlight in step.
          final liveQueue = sheetRef.watch(playbackQueueProvider);
          final currentId = sheetRef.watch(currentSongProvider)?.id;
          final isPlaying = sheetRef.watch(isPlayingProvider);

          return SafeArea(
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
                const SizedBox(height: 12),
                Text(
                  l10n.queue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SparkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: liveQueue.length,
                    itemBuilder: (context, i) {
                      final song = liveQueue[i];
                      final isCurrent = song.id == currentId;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isCurrent && isPlaying
                              ? LucideIcons.volume2
                              : LucideIcons.music,
                          size: 18,
                          color: isCurrent
                              ? SparkColors.accent
                              : SparkColors.textTertiary,
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: isCurrent
                                ? SparkColors.accent
                                : SparkColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: SparkColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          // The list above is playbackQueue, so this is a
                          // playback-list index, not an "up next" one.
                          sheetRef
                              .read(playerProvider.notifier)
                              .playPlaylistIndex(i);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.title,
    required this.isFavorite,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onFavorite,
    required this.onSleepTimer,
  });

  final String title;
  final bool isFavorite;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final VoidCallback onFavorite;
  final VoidCallback onSleepTimer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(sleepTimerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(LucideIcons.chevronDown, size: 22),
            color: SparkColors.textPrimary,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SparkColors.textPrimary,
                  ),
                ),
                // The countdown replaces nothing and only appears while a timer
                // is running, so it cannot be mistaken for track metadata.
                if (remaining != null)
                  Text(
                    formatCountdown(remaining),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SparkColors.accent,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSleepTimer,
            tooltip: context.l10n.sleepTimer,
            icon: Icon(
              remaining == null ? LucideIcons.moon : LucideIcons.moonStar,
              size: 22,
            ),
            color: remaining == null
                ? SparkColors.textPrimary
                : SparkColors.accent,
          ),
          IconButton(
            onPressed: onToggleLyrics,
            tooltip: context.l10n.lyrics,
            icon: const Icon(LucideIcons.alignLeft, size: 22),
            color: showLyrics ? SparkColors.accent : SparkColors.textPrimary,
          ),
          IconButton(
            onPressed: onFavorite,
            tooltip: isFavorite ? 'Remove from liked' : 'Add to liked',
            icon: SparkHeart(
              filled: isFavorite,
              size: 22,
              color: isFavorite ? SparkColors.accent : SparkColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular cover, slowly rotating while playing, wrapped in a halo tinted
/// by the cover's own dominant colour.
class _Artwork extends ConsumerStatefulWidget {
  const _Artwork({this.albumArt, this.filePath, required this.isPlaying});

  final String? albumArt;
  final String? filePath;
  final bool isPlaying;

  @override
  ConsumerState<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends ConsumerState<_Artwork>
    with SingleTickerProviderStateMixin {
  /// Slow enough to read as a turning record rather than a loading spinner.
  static const Duration _turnPeriod = Duration(seconds: 26);

  /// The halo is this much wider than the disc, so the disc is scaled down by
  /// the same factor to keep the whole thing inside its box.
  static const double _haloScale = 1.16;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _turnPeriod);
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(_Artwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      // Stop where it is rather than resetting, so a pause does not jump.
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Falls back to the accent when there is no cover, or extraction fails.
    final glow =
        ref.watch(dominantColorForArtProvider(widget.albumArt)).value ??
        SparkColors.accent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = MediaQuery.of(context).size.width * 0.78;
        final available = [
          constraints.maxWidth,
          constraints.maxHeight,
          cap,
        ].reduce((a, b) => a < b ? a : b);
        final outer = available.isFinite && available > 0 ? available : cap;
        final disc = outer / _haloScale;

        return SizedBox(
          width: outer,
          height: outer,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: 0.30),
                      glow.withValues(alpha: 0.10),
                      glow.withValues(alpha: 0.0),
                    ],
                    stops: const [0.55, 0.78, 1.0],
                  ),
                ),
              ),
              Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.42),
                      blurRadius: 46,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: RotationTransition(
                  turns: _controller,
                  child: ClipOval(
                    child: widget.albumArt != null
                        ? CachedImageWidget(
                            imagePath: widget.albumArt!,
                            audioSourcePath: widget.filePath,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: SparkColors.surfaceHigh,
                            child: Icon(
                              LucideIcons.music,
                              size: 56,
                              color: SparkColors.textTertiary,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _Controls extends StatelessWidget {
  const _Controls({
    required this.isPlaying,
    required this.isShuffle,
    required this.onShuffle,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onQueue,
  });

  final bool isPlaying;
  final bool isShuffle;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: onShuffle,
          icon: const Icon(LucideIcons.shuffle, size: 22),
          color: isShuffle ? SparkColors.accent : SparkColors.textSecondary,
        ),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(LucideIcons.skipBack, size: 30),
          color: SparkColors.textPrimary,
        ),
        // The one loud element in the app: a solid lime disc.
        Semantics(
          button: true,
          label: isPlaying ? 'Pause' : 'Play',
          child: Material(
            color: SparkColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onToggle,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(
                  isPlaying ? LucideIcons.pause : LucideIcons.play,
                  size: 28,
                  color: SparkColors.onAccent,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(LucideIcons.skipForward, size: 30),
          color: SparkColors.textPrimary,
        ),
        IconButton(
          onPressed: onQueue,
          icon: const Icon(LucideIcons.listMusic, size: 22),
          color: SparkColors.textSecondary,
        ),
      ],
    );
  }
}
