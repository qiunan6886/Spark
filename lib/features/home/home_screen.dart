import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/data/repositories/song_repository.dart';
import 'package:spark/features/library/add_music_folder.dart';
import 'package:spark/features/library/album_detail_screen.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/home_carousel.dart';
import 'package:spark/widgets/recent_strip.dart';
import 'package:spark/widgets/spark_mark.dart';
import 'package:spark/widgets/spark_mini_player.dart';

/// Home tab: greeting header, quick filters, a Curated card, the recently-added
/// albums, and online recommendations.
///
/// The album sections are derived from the scanned library. "Curated" surfaces
/// the most recent album -- or, with no library at all, the first online
/// recommendation -- which is honest about what the app actually knows.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Always the whole library, newest first. The quick-filter chips that used
    // to sit under the greeting were removed: filtering the home list was never
    // what anyone wanted here, and Library already has its own chips.
    final albumsAsync = ref.watch(homeFeedProvider(HomeFilter.all));

    return Scaffold(
      backgroundColor: SparkColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: SparkColors.headerGlow),
        child: SafeArea(
          bottom: false,
          child: albumsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: SparkColors.accent),
            ),
            error: (error, _) => _EmptyState(
              title: l10n.libraryEmptyTitle,
              body: '$error',
            ),
            data: (albums) {
              final libraryEmpty =
                  ref.watch(songsByAlbumProvider).value?.isEmpty ?? true;

              final heroAlbum = albums.isNotEmpty ? albums.first : null;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      greeting: _greetingText(
                        l10n,
                        ref.watch(greetingProvider),
                      ),
                      onGreetingTap: () =>
                          ref.read(greetingProvider.notifier).next(),
                      onSearch: () => ref
                          .read(navigationIndexProvider.notifier)
                          .setIndex(2),
                      onLiked: () {
                        // Land on Library with the Liked Songs chip selected --
                        // what a heart button promises.
                        ref.read(libraryFilterProvider.notifier).setFilter(2);
                        ref.read(navigationIndexProvider.notifier).setIndex(1);
                      },
                    ),
                  ),
                  // One card that pages between the collections, rather than
                  // three stacked down the page.
                  SliverToBoxAdapter(
                    child: _CuratedCarousel(
                      heroAlbum: heroAlbum,
                      onPlay: (songs) => _playCollection(songs),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _RecentlyPlayedStrip(
                      onPlay: (songs, index) => _playOnline(songs, index),
                    ),
                  ),
                  if (albums.isEmpty)
                    SliverToBoxAdapter(
                      // Distinguish "no music at all" from "this filter matched
                      // nothing": only the first wants an Add-folder button.
                      child: libraryEmpty
                          ? _EmptyState(
                              title: l10n.libraryEmptyTitle,
                              body: l10n.libraryEmptyBody,
                              action: const AddMusicFolderButton(),
                            )
                          : _EmptyState(
                              title: l10n.filterEmptyTitle,
                              body: l10n.filterEmptyBody,
                            ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: l10n.sectionRecentlyAdded,
                        onSeeAll: () {
                          ref.read(libraryFilterProvider.notifier).setFilter(0);
                          ref
                              .read(navigationIndexProvider.notifier)
                              .setIndex(1);
                        },
                      ),
                    ),
                    SliverList.builder(
                      itemCount: albums.length,
                      itemBuilder: (context, i) => _AlbumRow(
                        album: albums[i],
                        onPlay: () => _playAlbum(albums[i].songs),
                        onOpen: () => _openAlbum(context, albums[i]),
                      ),
                    ),
                  ],
                  // Keep the last row clear of the mini player + nav bar.
                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _playAlbum(List<Song> songs) {
    if (songs.isEmpty) return;
    ref.read(playerProvider.notifier).play(songs.first, playlist: songs);
  }

  void _openAlbum(BuildContext context, AlbumGroup album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumDetailScreen(album: album),
      ),
    );
  }

  /// Plays an online recommendation, queueing the rest of the list behind it.
  void _playOnline(List<Song> songs, int index) {
    ref
        .read(playerProvider.notifier)
        .play(songs[index], playlist: songs);
  }

  /// Plays a whole generated collection from its first track.
  void _playCollection(List<Song> songs) {
    if (songs.isEmpty) return;
    ref.read(playerProvider.notifier).play(songs.first, playlist: songs);
  }
}

/// Recently played, as a horizontal cover strip.
///
/// Hidden entirely until something has been played, so a fresh install does not
/// get an empty heading.
class _RecentlyPlayedStrip extends ConsumerWidget {
  const _RecentlyPlayedStrip({required this.onPlay});

  final void Function(List<Song> songs, int index) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(recentlyPlayedProvider).value;
    if (songs == null || songs.isEmpty) return const SizedBox.shrink();

    return RecentStrip(
      title: context.l10n.recentlyPlayed,
      songs: songs,
      onPlay: (index) => onPlay(songs, index),
    );
  }
}

/// The Curated area: one paging card covering the newest album, the daily mix
/// and the personalised pick.
///
/// Pages whose data is not ready are left out rather than shown empty, so the
/// carousel is never a blank card -- and with a single page it degrades to a
/// plain hero with no dots and no timer.
class _CuratedCarousel extends ConsumerWidget {
  const _CuratedCarousel({required this.heroAlbum, required this.onPlay});

  final AlbumGroup? heroAlbum;
  final void Function(List<Song> songs) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final daily = ref.watch(dailyMixProvider).value;
    final forYou = ref.watch(forYouProvider).value;

    final cards = <HomeCarouselCard>[
      if (heroAlbum != null && heroAlbum!.songs.isNotEmpty)
        HomeCarouselCard(
          title: heroAlbum!.albumName,
          subtitle:
              '${heroAlbum!.albumArtist} · '
              '${l10n.songCountShort(heroAlbum!.songs.length)}',
          songs: heroAlbum!.songs,
          icon: LucideIcons.disc3,
        ),
      if (daily != null && !daily.isEmpty)
        HomeCarouselCard(
          title: l10n.dailyMix,
          subtitle: l10n.dailyMixSubtitle(daily.songs.length),
          songs: daily.songs,
          icon: LucideIcons.calendarDays,
        ),
      if (forYou != null && !forYou.isEmpty)
        HomeCarouselCard(
          title: l10n.forYou,
          subtitle: forYou.builtFromLibrary
              ? l10n.forYouSubtitle(forYou.songs.length)
              : l10n.forYouNoHistory,
          songs: forYou.songs,
          icon: LucideIcons.sparkles,
        ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

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
            l10n.sectionCurated,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: SparkColors.textPrimary,
            ),
          ),
        ),
        HomeCarousel(cards: cards, onPlay: onPlay),
      ],
    );
  }
}

/// Maps a rotating index to one of the localized positive greetings.
///
/// The phrases live in the ARB files rather than in Dart so both languages stay
/// in step; this is the only place that has to know their order.
String _greetingText(L10n l10n, int index) {
  return switch (index) {
    0 => l10n.greeting0,
    1 => l10n.greeting1,
    2 => l10n.greeting2,
    3 => l10n.greeting3,
    4 => l10n.greeting4,
    5 => l10n.greeting5,
    6 => l10n.greeting6,
    7 => l10n.greeting7,
    8 => l10n.greeting8,
    9 => l10n.greeting9,
    _ => l10n.greeting,
  };
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.onGreetingTap,
    required this.onSearch,
    required this.onLiked,
  });

  final String greeting;
  final VoidCallback onGreetingTap;
  final VoidCallback onSearch;
  final VoidCallback onLiked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        8,
        SparkSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Was a bare gradient circle, which read as an account avatar
              // that did nothing. Spark has no accounts, so the space now
              // carries the brand mark instead.
              SparkMark(size: 40, background: SparkColors.surfaceHigh),
              const Spacer(),
              _CircleButton(icon: LucideIcons.search, onTap: onSearch),
              const SizedBox(width: 10),
              _CircleButton(icon: LucideIcons.heart, onTap: onLiked),
            ],
          ),
          const SizedBox(height: 20),
          // Tapping cycles to the next phrase, so the rotation can be driven by
          // the user instead of only by the timer.
          GestureDetector(
            onTap: onGreetingTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              greeting,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: SparkColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        0,
        SparkSpacing.page,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: SparkColors.textPrimary,
              ),
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(SparkRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Text(
                  context.l10n.seeAll,
                  style: TextStyle(
                    fontSize: 13,
                    color: SparkColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({
    required this.album,
    required this.onPlay,
    required this.onOpen,
  });

  final AlbumGroup album;
  final VoidCallback onPlay;

  /// Opens the album's track list. The row used to just play it, which left no
  /// way to see what was on the album or start from the middle.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SparkSpacing.page, 0, SparkSpacing.page, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(SparkRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SparkArtwork(
                  albumArt: album.songs.first.albumArt,
                  filePath: album.songs.first.filePath,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        album.albumName,
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
                        '${album.albumArtist} · ${context.l10n.songCountShort(album.songs.length)}',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body, this.action});

  final String title;
  final String body;

  /// Optional call to action, shown under the copy. The empty library passes the
  /// add-folder button; error states leave it null.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.music,
            size: 44,
            color: SparkColors.textTertiary,
          ),
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
          if (action != null) ...[
            const SizedBox(height: 22),
            action!,
          ],
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SparkColors.surfaceHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 19, color: SparkColors.textPrimary),
        ),
      ),
    );
  }
}

/// Pill-shaped filter chip. Unselected is a flat surface; selected flips to the
/// lime accent with dark content.
class SparkChip extends StatelessWidget {
  const SparkChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SparkRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? SparkColors.accent : SparkColors.surfaceHigh,
          borderRadius: BorderRadius.circular(SparkRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? SparkColors.onAccent : SparkColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
