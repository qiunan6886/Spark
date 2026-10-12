import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audius_service.dart';
import '../services/jamendo_service.dart';
import 'songs_provider.dart';

// ============================================================================
// Genre browsing
// ============================================================================

/// A browsable genre, holding the value each API expects for it.
///
/// The two catalogues do not share a vocabulary: Audius uses its own genre
/// names (`Hip-Hop/Rap`) while Jamendo uses lowercase tags (`hiphop`), so the
/// mapping lives here rather than in either service.
class OnlineGenre {
  const OnlineGenre({required this.id, this.audiusGenre, this.jamendoTag});

  /// Stable key, also used to look up the localised label.
  final String id;
  final String? audiusGenre;
  final String? jamendoTag;
}

const List<OnlineGenre> kOnlineGenres = [
  OnlineGenre(
    id: 'electronic',
    audiusGenre: 'Electronic',
    jamendoTag: 'electronic',
  ),
  OnlineGenre(id: 'rock', audiusGenre: 'Rock', jamendoTag: 'rock'),
  OnlineGenre(
    id: 'hipHop',
    audiusGenre: 'Hip-Hop/Rap',
    jamendoTag: 'hiphop',
  ),
  OnlineGenre(id: 'jazz', audiusGenre: 'Jazz', jamendoTag: 'jazz'),
  OnlineGenre(id: 'pop', audiusGenre: 'Pop', jamendoTag: 'pop'),
  OnlineGenre(
    id: 'classical',
    audiusGenre: 'Classical',
    jamendoTag: 'classical',
  ),
  OnlineGenre(id: 'ambient', audiusGenre: 'Ambient', jamendoTag: 'ambient'),
  // Audius has no folk genre; its feed simply ignores the filter.
  OnlineGenre(id: 'folk', jamendoTag: 'folk'),
];

OnlineGenre? onlineGenreById(String? id) {
  if (id == null) return null;
  for (final genre in kOnlineGenres) {
    if (genre.id == id) return genre;
  }
  return null;
}

/// Selected genre id, or null for "all".
final onlineGenreProvider = NotifierProvider<OnlineGenreNotifier, String?>(
  OnlineGenreNotifier.new,
);

class OnlineGenreNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = state == id ? null : id;
  }
}

// ============================================================================
// Paged feeds
// ============================================================================

/// One page of a streaming feed plus the bookkeeping needed to ask for more.
class OnlineFeed<T> {
  const OnlineFeed({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;

  OnlineFeed<T> copyWith({List<T>? items, bool? hasMore, bool? isLoadingMore}) {
    return OnlineFeed<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Shared offset paging over an API that takes `limit`/`offset`.
class PagedFeed<T> {
  PagedFeed({required Future<List<T>> Function(int limit, int offset) fetch})
    : _fetch = fetch;

  /// 30 at a time: enough to fill a phone screen several times over while
  /// keeping a single request small.
  static const int pageSize = 30;

  /// Attempts per page before an empty answer is believed. Three consecutive
  /// empty responses are rare enough (roughly 2% at the measured rate) that a
  /// real "no results" is not worth more quota than this.
  static const int maxAttempts = 3;

  final Future<List<T>> Function(int limit, int offset) _fetch;
  int _offset = 0;
  bool hasMore = true;

  /// Loads the first page and resets paging state.
  Future<List<T>> reset() async {
    _offset = 0;
    final page = await _fetchWithRetry(0);
    _offset = page.length;
    hasMore = page.length >= PagedFeed.pageSize;
    return page;
  }

  /// Loads the next page, or nothing once the feed is exhausted.
  Future<List<T>> next() async {
    if (!hasMore) return const [];

    final page = await _fetchWithRetry(_offset);
    _offset += page.length;
    hasMore = page.length >= PagedFeed.pageSize;
    return page;
  }

  /// Fetches one page, retrying an empty answer.
  ///
  /// Measured behaviour: Jamendo answers roughly one request in four with
  /// `status: success, code: 0, results_count: 0` -- indistinguishable from a
  /// genuine "no matches", and it happens even with seconds between requests.
  /// Audius shows the same pattern under load. Retrying is the only available
  /// mitigation, so three attempts are made before accepting an empty page.
  /// This applies to the first page too: without it a throttled first request
  /// would leave the section reading "nothing found" with no way to ask again.
  Future<List<T>> _fetchWithRetry(int offset) async {
    for (var attempt = 0; attempt < PagedFeed.maxAttempts; attempt++) {
      final page = await _fetch(PagedFeed.pageSize, offset);
      if (page.isNotEmpty) return page;
    }
    return const [];
  }
}

// ---- Audius ----------------------------------------------------------------

final audiusServiceProvider = Provider<AudiusService>((ref) => AudiusService());

final audiusFeedProvider =
    AsyncNotifierProvider<AudiusFeedNotifier, OnlineFeed<AudiusTrack>>(
      AudiusFeedNotifier.new,
    );

class AudiusFeedNotifier extends AsyncNotifier<OnlineFeed<AudiusTrack>> {
  PagedFeed<AudiusTrack>? _feed;

  @override
  Future<OnlineFeed<AudiusTrack>> build() async {
    final query = ref.watch(searchQueryProvider).trim();
    final genre = onlineGenreById(ref.watch(onlineGenreProvider))?.audiusGenre;
    final service = ref.watch(audiusServiceProvider);

    final feed = _feed = PagedFeed<AudiusTrack>(
      fetch: (limit, offset) => query.isNotEmpty
          ? service.search(query, limit: limit, offset: offset)
          : service.trending(limit: limit, offset: offset, genre: genre),
    );

    final page = await feed.reset();
    return OnlineFeed(items: page, hasMore: feed.hasMore);
  }

  Future<void> loadMore() async {
    final feed = _feed;
    final current = state.value;
    if (feed == null ||
        current == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final more = await feed.next();
    state = AsyncData(
      OnlineFeed(
        items: [...current.items, ...more],
        hasMore: feed.hasMore,
      ),
    );
  }
}

// ---- Jamendo (free non-commercial Client ID) -------------------------------

/// Pre-filled with the Client ID this build was provisioned with, so online
/// music works on first launch; editable in Settings since the ID belongs to
/// whoever registered the app.
const String kDefaultJamendoClientId = 'ab4e0ba0';

class JamendoClientIdNotifier extends Notifier<String> {
  static const _prefsKey = 'spark.jamendo_client_id';

  @override
  String build() {
    _restore();
    return kDefaultJamendoClientId;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null || !ref.mounted) return;
    state = stored;
  }

  Future<void> setClientId(String value) async {
    final trimmed = value.trim();
    if (state == trimmed) return;
    state = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, trimmed);
  }
}

final jamendoClientIdProvider =
    NotifierProvider<JamendoClientIdNotifier, String>(
      JamendoClientIdNotifier.new,
    );

final jamendoServiceProvider = Provider<JamendoService>((ref) {
  return JamendoService(clientId: ref.watch(jamendoClientIdProvider));
});

final jamendoFeedProvider =
    AsyncNotifierProvider<JamendoFeedNotifier, OnlineFeed<JamendoTrack>>(
      JamendoFeedNotifier.new,
    );

class JamendoFeedNotifier extends AsyncNotifier<OnlineFeed<JamendoTrack>> {
  PagedFeed<JamendoTrack>? _feed;

  @override
  Future<OnlineFeed<JamendoTrack>> build() async {
    final query = ref.watch(searchQueryProvider).trim();
    final genre = onlineGenreById(ref.watch(onlineGenreProvider))?.jamendoTag;
    final service = ref.watch(jamendoServiceProvider);
    if (!service.isConfigured) {
      return const OnlineFeed(items: [], hasMore: false);
    }

    final feed = _feed = PagedFeed<JamendoTrack>(
      fetch: (limit, offset) => query.isNotEmpty
          ? service.search(query, limit: limit, offset: offset)
          : service.trending(limit: limit, offset: offset, tag: genre),
    );

    final page = await feed.reset();
    return OnlineFeed(items: page, hasMore: feed.hasMore);
  }

  Future<void> loadMore() async {
    final feed = _feed;
    final current = state.value;
    if (feed == null ||
        current == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final more = await feed.next();
    state = AsyncData(
      OnlineFeed(
        items: [...current.items, ...more],
        hasMore: feed.hasMore,
      ),
    );
  }
}
