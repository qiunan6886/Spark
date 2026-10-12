// Unit checks for the shared paging bookkeeping behind the online feeds.
//
//   flutter test test/paged_feed_test.dart
//
// Both APIs answer bursts with an empty page rather than an error, so the
// "retry once before deciding the feed ended" rule is the interesting part
// here: without it a single rate-limited response would silently truncate the
// list for the rest of the session.
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/providers/online_music_provider.dart';

void main() {
  group('PagedFeed', () {
    test('asks for successive offsets and stops at a short page', () async {
      final requests = <int>[];
      final feed = PagedFeed<int>(
        fetch: (limit, offset) async {
          requests.add(offset);
          expect(limit, PagedFeed.pageSize);
          if (offset >= 60) return const []; // exhausted
          return List.generate(PagedFeed.pageSize, (i) => offset + i);
        },
      );

      final first = await feed.reset();
      expect(first.length, PagedFeed.pageSize);
      expect(feed.hasMore, isTrue);

      final second = await feed.next();
      expect(second.first, PagedFeed.pageSize);
      expect(feed.hasMore, isTrue);

      // The exhausted page is retried maxAttempts times before giving up.
      await feed.next();
      expect(feed.hasMore, isFalse);

      // Once exhausted it must stop asking entirely.
      final before = requests.length;
      expect(await feed.next(), isEmpty);
      expect(requests.length, before);
    });

    test('retries empty pages instead of ending the feed', () async {
      var calls = 0;
      final feed = PagedFeed<int>(
        fetch: (limit, offset) async {
          calls++;
          // First page is empty twice, then returns real data.
          if (calls <= 2) return const [];
          return List.generate(limit, (i) => i);
        },
      );

      final page = await feed.reset();
      expect(calls, 3, reason: 'two empty pages must be retried');
      expect(page.length, PagedFeed.pageSize);
      expect(feed.hasMore, isTrue);
    });

    test('gives up after maxAttempts empty pages', () async {
      var calls = 0;
      final feed = PagedFeed<int>(
        fetch: (limit, offset) async {
          calls++;
          return const [];
        },
      );

      final page = await feed.reset();
      expect(page, isEmpty);
      expect(calls, PagedFeed.maxAttempts);
      expect(feed.hasMore, isFalse);
    });

    test('a full page means there is probably more', () async {
      final feed = PagedFeed<int>(
        fetch: (limit, offset) async => List.generate(limit, (i) => i),
      );
      await feed.reset();
      expect(feed.hasMore, isTrue);
    });

    test('a short page means the feed ended', () async {
      final feed = PagedFeed<int>(fetch: (limit, offset) async => const [1, 2]);
      await feed.reset();
      expect(feed.hasMore, isFalse);
    });

    test('reset rewinds the offset', () async {
      final offsets = <int>[];
      final feed = PagedFeed<int>(
        fetch: (limit, offset) async {
          offsets.add(offset);
          return List.generate(limit, (i) => offset + i);
        },
      );

      await feed.reset();
      await feed.next();
      await feed.reset();
      await feed.next();

      expect(offsets, [0, PagedFeed.pageSize, 0, PagedFeed.pageSize]);
    });
  });

  group('genres', () {
    test('every genre maps to at least one catalogue', () {
      for (final genre in kOnlineGenres) {
        expect(
          genre.audiusGenre != null || genre.jamendoTag != null,
          isTrue,
          reason: '${genre.id} maps to neither API',
        );
      }
    });

    test('audius genre values match the API vocabulary', () {
      // These are the exact strings audius echoes back; a typo would silently
      // return an empty list rather than an error.
      expect(onlineGenreById('hipHop')?.audiusGenre, 'Hip-Hop/Rap');
      expect(onlineGenreById('electronic')?.audiusGenre, 'Electronic');
      expect(onlineGenreById('classical')?.audiusGenre, 'Classical');
    });

    test('jamendo tags are lowercase', () {
      for (final genre in kOnlineGenres) {
        final tag = genre.jamendoTag;
        if (tag == null) continue;
        expect(tag, tag.toLowerCase());
      }
    });

    test('unknown and null ids resolve to null', () {
      expect(onlineGenreById(null), isNull);
      expect(onlineGenreById('nope'), isNull);
    });
  });
}
