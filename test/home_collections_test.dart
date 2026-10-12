// Checks for the generated Home collections.
//
//   flutter test test/home_collections_test.dart
//
// The Daily mix promises the same tracks all day and a different set tomorrow.
// Both halves of that are easy to break silently -- using `Random()` without a
// seed, or seeding from something that moves -- and neither shows up as a
// failure on screen, so they are pinned down here.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/providers/home_collections_provider.dart';

/// Mirrors what the provider does to the library.
List<int> dailyOrder(List<int> library, DateTime when) {
  return [...library]..shuffle(Random(daySeed(when)));
}

void main() {
  group('daySeed', () {
    test('is stable within a day regardless of the time', () {
      final morning = DateTime(2026, 10, 11, 6, 30);
      final night = DateTime(2026, 10, 11, 23, 59, 59);
      expect(daySeed(morning), daySeed(night));
    });

    test('changes at midnight', () {
      expect(
        daySeed(DateTime(2026, 10, 11, 23, 59)),
        isNot(daySeed(DateTime(2026, 10, 12, 0, 1))),
      );
      expect(
        daySeed(DateTime(2026, 10, 31)),
        isNot(daySeed(DateTime(2026, 11, 1))),
      );
    });

    test('distinguishes months and years that share a day number', () {
      expect(
        daySeed(DateTime(2026, 3, 1)),
        isNot(daySeed(DateTime(2026, 1, 3))),
      );
      expect(
        daySeed(DateTime(2026, 10, 11)),
        isNot(daySeed(DateTime(2027, 10, 11))),
      );
    });
  });

  group('daily shuffle', () {
    final library = List<int>.generate(60, (i) => i);

    test('produces the same order twice in one day', () {
      final first = dailyOrder(library, DateTime(2026, 10, 11, 8));
      final second = dailyOrder(library, DateTime(2026, 10, 11, 21));
      expect(first, second);
    });

    test('produces a different order the next day', () {
      final today = dailyOrder(library, DateTime(2026, 10, 11));
      final tomorrow = dailyOrder(library, DateTime(2026, 10, 12));
      expect(today, isNot(tomorrow));
    });

    test('keeps every track, so the mix is a reordering not a filter', () {
      final order = dailyOrder(library, DateTime(2026, 10, 11));
      expect(order.toSet(), library.toSet());
    });
  });

  group('HomeCollection', () {
    test('tracks its origin', () {
      const fromLibrary = HomeCollection(id: 'daily', songs: []);
      expect(fromLibrary.builtFromLibrary, isTrue);
      expect(fromLibrary.isEmpty, isTrue);

      const fromStreaming = HomeCollection(
        id: 'forYou',
        songs: [],
        builtFromLibrary: false,
      );
      expect(fromStreaming.builtFromLibrary, isFalse);
    });
  });
}
