import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/features/library/add_to_playlist.dart';
import 'package:spark/features/library/download_actions.dart';
import 'package:spark/widgets/selectable_song_list.dart';
import 'package:spark/widgets/spark_mini_player.dart';
import 'package:spark/widgets/swipe_actions.dart';

/// Search tab: the local library plus two streaming catalogues.
///
/// Results are grouped by source under their own headings, and the streaming
/// groups page in automatically as the list nears its end.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final ScrollController _scrollController = ScrollController();

  /// How close to the end of the list triggers the next page. Roughly a screen
  /// and a half, so the new rows are usually in place before they are reached.
  static const double _loadMoreThreshold = 900;

  @override
  void initState() {
    super.initState();
    // Seeded from the provider so a query survives switching tabs; the screen
    // lives in an IndexedStack and is not rebuilt from scratch.
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Loads the next page of both feeds once the list nears its end.
  ///
  /// Fire-and-forget: loadMore() ignores calls that arrive while a page is
  /// already in flight or once a feed is exhausted, so this does not need to
  /// track that itself.
  void _onScroll() => _maybeLoadMore();

  void _maybeLoadMore() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) return;

    ref.read(audiusFeedProvider.notifier).loadMore();
    ref.read(jamendoFeedProvider.notifier).loadMore();
  }

  /// Keeps the field in step with the provider, which stays the source of truth
  /// (the field is only one editor of it).
  void _syncFromProvider(String query) {
    if (_controller.text == query) return;
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    _syncFromProvider(query);

    final trimmed = query.trim();

    // Trending while the box is empty, a search once it has text. Both feeds
    // re-run when the query or the selected genre changes, because each
    // notifier watches them in build().
    final audiusFeed = ref.watch(audiusFeedProvider);
    final jamendoConfigured = ref
        .watch(jamendoClientIdProvider)
        .trim()
        .isNotEmpty;
    final jamendoFeed = ref.watch(jamendoFeedProvider);
    final selectedGenre = ref.watch(onlineGenreProvider);

    // A list too short to scroll emits no scroll events, so the end-of-list
    // trigger would never fire and the user could be left with a single page.
    // Re-checking after each frame covers that case; loadMore() is a no-op
    // unless there is genuinely more to fetch, so this settles on its own.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());

    return Scaffold(
      backgroundColor: SparkColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpacing.page,
                12,
                SparkSpacing.page,
                12,
              ),
              child: _SearchField(
                controller: _controller,
                hint: l10n.searchHint,
                onChanged: (value) =>
                    ref.read(searchQueryProvider.notifier).setQuery(value),
                onClear: () {
                  _controller.clear();
                  ref.read(searchQueryProvider.notifier).clear();
                },
              ),
            ),
            Expanded(
              // Local results and online results share one scroll view, each
              // under its own heading, so it is always clear which library a
              // track is coming from.
              child: CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (trimmed.isEmpty) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeading(title: l10n.onlineDiscover),
                    ),
                    SliverToBoxAdapter(
                      child: _GenreChips(
                        selected: selectedGenre,
                        onSelect: (id) => ref
                            .read(onlineGenreProvider.notifier)
                            .select(id),
                      ),
                    ),
                  ] else ...[
                    SliverToBoxAdapter(
                      child: _SectionHeading(title: l10n.localResults),
                    ),
                    ...results.when(
                      loading: () => [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: SparkColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                      error: (error, _) => [
                        SliverToBoxAdapter(
                          child: _Message(
                            icon: LucideIcons.circleAlert,
                            title: l10n.searchEmptyTitle,
                            body: '$error',
                          ),
                        ),
                      ],
                      data: (songs) => [
                        if (songs.isEmpty)
                          SliverToBoxAdapter(
                            child: _InlineNote(
                              text: l10n.searchNoResults(trimmed),
                            ),
                          )
                        else
                          SliverList.builder(
                            itemCount: songs.length,
                            itemBuilder: (context, i) {
                              final song = songs[i];
                              return SwipeActions(
                                actions: [
                                  SwipeAction(
                                    icon: LucideIcons.heart,
                                    label: l10n.favorite,
                                    onPressed: () => ref
                                        .read(favoritesProvider.notifier)
                                        .addFavorite(song.id),
                                  ),
                                  SwipeAction(
                                    icon: LucideIcons.listPlus,
                                    label: l10n.addToPlaylist,
                                    color: SparkColors.textSecondary,
                                    onPressed: () => showAddToPlaylistSheet(
                                      context,
                                      ref,
                                      song,
                                    ),
                                  ),
                                ],
                                child: _ResultRow(
                                  song: song,
                                  onTap: () => ref
                                      .read(playerProvider.notifier)
                                      .play(song, playlist: songs),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: _OnlineSource(
                      title: l10n.onlineFromAudius,
                      sourceLabel: l10n.onlineStreaming,
                      songs: audiusFeed.whenData(
                        (feed) => [for (final t in feed.items) t.toSong()],
                      ),
                      isLoadingMore: audiusFeed.value?.isLoadingMore ?? false,
                      unavailableText: l10n.onlineUnavailable,
                      emptyText: l10n.onlineNoResults,
                      onPlay: (song, queue) => ref
                          .read(playerProvider.notifier)
                          .play(song, playlist: queue),
                    ),
                  ),
                  // Hidden entirely when no Client ID is set, rather than
                  // claiming "nothing found" for a source that cannot be asked.
                  if (jamendoConfigured)
                    SliverToBoxAdapter(
                      child: _OnlineSource(
                        title: l10n.onlineFromJamendo,
                        sourceLabel: l10n.onlineStreaming,
                        songs: jamendoFeed.whenData(
                          (feed) => [for (final t in feed.items) t.toSong()],
                        ),
                        isLoadingMore:
                            jamendoFeed.value?.isLoadingMore ?? false,
                        unavailableText: l10n.onlineUnavailable,
                        emptyText: l10n.onlineNoResults,
                        onPlay: (song, queue) => ref
                            .read(playerProvider.notifier)
                            .play(song, playlist: queue),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Container(
          decoration: BoxDecoration(
            color: SparkColors.surface,
            borderRadius: BorderRadius.circular(SparkRadius.pill),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                LucideIcons.search,
                size: 19,
                color: SparkColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    fontSize: 15,
                    color: SparkColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: SparkColors.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (value.text.isNotEmpty)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: SparkColors.textSecondary,
                )
              else
                const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpacing.page,
          vertical: 8,
        ),
        child: Row(
          children: [
            SparkArtwork(
              albumArt: song.albumArt,
              filePath: song.filePath,
              size: 56,
            ),
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
            const SizedBox(width: 12),
            Icon(LucideIcons.play, size: 20, color: SparkColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Small heading above a result group, with an optional source label.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        20,
        SparkSpacing.page,
        8,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SparkColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 12, color: SparkColors.textTertiary),
            ),
        ],
      ),
    );
  }
}

/// A muted one-line note, used where a whole empty-state block would be too
/// heavy (an empty group inside a list that has other groups).
class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpacing.page,
        4,
        SparkSpacing.page,
        16,
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: SparkColors.textTertiary),
      ),
    );
  }
}

/// One streaming provider's results, under its own heading.
///
/// Each source is listed separately rather than merged: they have different
/// catalogues and different licensing, and a listener looking at a track
/// deserves to know which one it came from.
///
/// Streaming tracks play through the Android player until they are cached; once
/// cached they are ordinary files and eligible for the direct-USB engine.
class _OnlineSource extends ConsumerWidget {
  const _OnlineSource({
    required this.title,
    required this.sourceLabel,
    required this.songs,
    required this.isLoadingMore,
    required this.unavailableText,
    required this.emptyText,
    required this.onPlay,
  });

  final String title;
  final String sourceLabel;
  final AsyncValue<List<Song>> songs;
  final bool isLoadingMore;
  final String unavailableText;
  final String emptyText;
  final void Function(Song song, List<Song> queue) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(title: title, trailing: sourceLabel),
        songs.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: SparkColors.accent,
                ),
              ),
            ),
          ),
          error: (error, _) => _InlineNote(text: unavailableText),
          data: (list) {
            if (list.isEmpty) return _InlineNote(text: emptyText);
            return Column(
              children: [
                SelectableSongList(
                  songs: list,
                  // Inside a sliver: no bounded height to expand into.
                  shrinkWrap: true,
                  onPlay: onPlay,
                  // No trailing button: the swipe action and the multi-select bar
                  // both cover saving a track offline, and the button was a third
                  // way to do the same thing.
                  swipeActionsFor: (song) =>
                      _offlineActions(context, ref, song),
                  selectionActions: [
                    SelectionAction(
                      icon: LucideIcons.download,
                      label: l10n.download,
                      onPressed: (picked) =>
                          saveSongsOffline(context, ref, picked),
                    ),
                    SelectionAction(
                      icon: LucideIcons.trash2,
                      label: l10n.removeDownload,
                      destructive: true,
                      onPressed: (picked) => removeDownloads(ref, picked),
                    ),
                  ],
                ),
                // Paging is driven by the scroll position, so there is no
                // button; this only shows that the next page is on its way.
                if (isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SparkColors.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Swipe actions for a streaming row.
///
/// A track that is already saved offers removal instead of a second download;
/// showing both would let the user save something twice. Icon-only, matching the
/// library rows.
List<SwipeAction> _offlineActions(
  BuildContext context,
  WidgetRef ref,
  Song song,
) {
  if (ref.read(isSongCachedProvider(song.id))) {
    return [
      SwipeAction(
        icon: LucideIcons.trash2,
        color: const Color(0xFFB3261E),
        onPressed: () => removeDownloads(ref, [song]),
      ),
    ];
  }
  return [
    SwipeAction(
      icon: LucideIcons.download,
      onPressed: () => saveSongsOffline(context, ref, [song]),
    ),
  ];
}

/// Genre filter for the browse feed. Only shown while the search box is empty:
/// during a search the query is what the user is filtering by.
class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SparkSpacing.page),
        children: [
          _GenreChip(
            label: l10n.onlineGenreAll,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final genre in kOnlineGenres)
            _GenreChip(
              label: _genreLabel(l10n, genre.id),
              selected: selected == genre.id,
              onTap: () => onSelect(genre.id),
            ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? SparkColors.accent : SparkColors.surface,
            borderRadius: BorderRadius.circular(SparkRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? SparkColors.background
                  : SparkColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

String _genreLabel(L10n l10n, String id) {
  switch (id) {
    case 'electronic':
      return l10n.onlineGenreElectronic;
    case 'rock':
      return l10n.onlineGenreRock;
    case 'hipHop':
      return l10n.onlineGenreHipHop;
    case 'jazz':
      return l10n.onlineGenreJazz;
    case 'pop':
      return l10n.onlineGenrePop;
    case 'classical':
      return l10n.onlineGenreClassical;
    case 'ambient':
      return l10n.onlineGenreAmbient;
    case 'folk':
      return l10n.onlineGenreFolk;
    default:
      return id;
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: SparkColors.textTertiary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: SparkColors.textPrimary,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: SparkColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
