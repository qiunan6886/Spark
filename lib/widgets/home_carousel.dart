import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/album_accent.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/spark_mini_player.dart' show SparkArtwork;

/// One page of the Home carousel.
@immutable
class HomeCarouselCard {
  const HomeCarouselCard({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<Song> songs;
  final IconData icon;
}

/// The Curated area: one card that pages between the collections.
///
/// Previously these were three separate cards stacked down the page, which took
/// most of the first screen. Combining them keeps the same visual language while
/// leaving room for the rest of Home.
class HomeCarousel extends ConsumerStatefulWidget {
  const HomeCarousel({
    super.key,
    required this.cards,
    required this.onPlay,
  });

  final List<HomeCarouselCard> cards;
  final void Function(List<Song> songs) onPlay;

  /// How long a page stays before the carousel moves on.
  static const Duration autoAdvanceInterval = Duration(seconds: 5);

  /// Height of the card.
  static const double cardHeight = 132;

  /// Gap between the card and the page dots.
  static const double dotsGap = 10;

  /// Height reserved for the page dots row.
  static const double dotsHeight = 20;

  @override
  ConsumerState<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends ConsumerState<HomeCarousel> {

  final PageController _controller = PageController();
  Timer? _autoAdvance;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void didUpdateWidget(HomeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The cards arrive asynchronously (two of them are futures), so the count
    // changes after the first frame; re-arm accordingly.
    if (oldWidget.cards.length != widget.cards.length) _scheduleNext();
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Arms the next automatic step.
  ///
  /// A one-shot timer restarted on every page change, rather than a periodic
  /// one: a periodic timer would also fire while the user is mid-swipe and
  /// could advance twice in quick succession.
  void _scheduleNext() {
    _autoAdvance?.cancel();
    if (widget.cards.length < 2) return;
    _autoAdvance = Timer(HomeCarousel.autoAdvanceInterval, _advance);
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    final next = (_page + 1) % widget.cards.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        0,
        SparkSpacing.page,
        SparkSpacing.section,
      ),
      child: Column(
        // Shrink-wraps: the carousel is placed in a scroll view, and declaring
        // this keeps its height equal to the sum of its parts.
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: HomeCarousel.cardHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.cards.length,
              onPageChanged: (index) {
                setState(() => _page = index);
                // Manual or automatic, give the new page its full dwell time.
                _scheduleNext();
              },
              itemBuilder: (context, i) => _CardFace(
                card: widget.cards[i],
                onPlay: () => widget.onPlay(widget.cards[i].songs),
              ),
            ),
          ),
          if (widget.cards.length > 1) ...[
            const SizedBox(height: HomeCarousel.dotsGap),
            SizedBox(
              height: HomeCarousel.dotsHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.cards.length; i++)
                    _Dot(active: i == _page),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? SparkColors.accent : SparkColors.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// The visible page: colour taken from its first track's artwork, exactly as the
/// old standalone cards did.
///
/// Deliberately flat -- no shadow, no offset layers. A shadow here is clipped by
/// the PageView's rectangular viewport, which cuts it off with a straight edge
/// and leaves a grey halo around the rounded corners; both read as stray
/// artefacts rather than as depth.
class _CardFace extends ConsumerWidget {
  const _CardFace({required this.card, required this.onPlay});

  final HomeCarouselCard card;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (card.songs.isEmpty) return const SizedBox.shrink();
    final lead = card.songs.first;

    final colorMode = ref.watch(albumColorModeProvider);
    final dominant = ref
        .watch(dominantColorForArtProvider(lead.albumArt))
        .value;
    final gradient = heroGradientFor(dominant, colorMode);
    final buttonColor = heroButtonColorFor(dominant, colorMode);

    return Container(
      height: HomeCarousel.cardHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(SparkRadius.hero),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: buttonColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.play,
                          size: 20,
                          color: SparkColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(card.icon, size: 20, color: Colors.black54),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(SparkRadius.card),
            child: SizedBox(
              width: HomeCarousel.cardHeight - 32,
              height: HomeCarousel.cardHeight - 32,
              child: SparkArtwork(
                albumArt: lead.albumArt,
                filePath: lead.filePath,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
