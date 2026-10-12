// Checks for the Home carousel.
//
//   flutter test test/home_carousel_test.dart
//
// The card pages itself every five seconds and must also follow a manual swipe.
// Both are timer-driven, and a one-shot timer that is not re-armed on a page
// change either stops after one step or fires mid-swipe -- neither shows up as
// a crash, so the timing is pinned down here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/models/song.dart';
import 'package:spark/widgets/home_carousel.dart';

Song _song(String id, String title) => Song(
  id: id,
  title: title,
  artist: 'Artist',
  duration: const Duration(seconds: 180),
  fileType: 'MP3',
  filePath: '/music/$id.mp3',
);

List<HomeCarouselCard> _cards() => [
  HomeCarouselCard(
    title: 'First',
    subtitle: 'one',
    songs: [_song('a', 'A')],
    icon: Icons.album,
  ),
  HomeCarouselCard(
    title: 'Second',
    subtitle: 'two',
    songs: [_song('b', 'B')],
    icon: Icons.album,
  ),
  HomeCarouselCard(
    title: 'Third',
    subtitle: 'three',
    songs: [_song('c', 'C')],
    icon: Icons.album,
  ),
];

Widget _wrap(List<HomeCarouselCard> cards, {void Function(List<Song>)? onPlay}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: HomeCarousel(cards: cards, onPlay: onPlay ?? (_) {}),
      ),
    ),
  );
}

/// Advances the fake clock without waiting for the tree to be fully idle, which
/// pumpAndSettle cannot do while a repeating timer keeps scheduling frames.
Future<void> _advance(WidgetTester tester, Duration by) async {
  await tester.pump(by);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('shows the first card and its dots', (tester) async {
    await tester.pumpWidget(_wrap(_cards()));
    await tester.pump();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('advances on its own after five seconds', (tester) async {
    await tester.pumpWidget(_wrap(_cards()));
    await tester.pump();

    // Not yet: the first page gets its full dwell time.
    await _advance(tester, const Duration(seconds: 4));
    expect(find.text('First'), findsOneWidget);

    await _advance(tester, const Duration(seconds: 1, milliseconds: 500));
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('keeps advancing, and wraps past the last card', (tester) async {
    await tester.pumpWidget(_wrap(_cards()));
    await tester.pump();

    await _advance(tester, HomeCarousel.autoAdvanceInterval);
    expect(find.text('Second'), findsOneWidget);

    await _advance(tester, HomeCarousel.autoAdvanceInterval);
    expect(find.text('Third'), findsOneWidget);

    // Back to the start rather than stopping at the end.
    await _advance(tester, HomeCarousel.autoAdvanceInterval);
    expect(find.text('First'), findsOneWidget);
  });

  testWidgets('a manual swipe moves on and re-arms the timer', (tester) async {
    await tester.pumpWidget(_wrap(_cards()));
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Second'), findsOneWidget);

    // The four seconds that would have advanced the first page must not advance
    // this one: the swipe restarted the dwell time.
    await _advance(tester, const Duration(seconds: 4));
    expect(find.text('Second'), findsOneWidget);

    await _advance(tester, const Duration(seconds: 1, milliseconds: 500));
    expect(find.text('Third'), findsOneWidget);
  });

  testWidgets('a single card does not page', (tester) async {
    await tester.pumpWidget(_wrap([_cards().first]));
    await tester.pump();

    expect(find.text('First'), findsOneWidget);
    await _advance(tester, const Duration(seconds: 12));
    expect(find.text('First'), findsOneWidget);
  });

  testWidgets('the play button reports the card it belongs to', (tester) async {
    List<Song>? picked;
    await tester.pumpWidget(
      _wrap(_cards(), onPlay: (songs) => picked = songs),
    );
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.play));
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.single.id, 'a');
  });

  testWidgets('renders nothing without cards', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pump();
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('the card sits flush, with nothing below it', (tester) async {
    // Regression: offset "stack" layers used to be painted behind the card and
    // peek out underneath, which read as a stray band rather than as depth. The
    // carousel is one flat card now.
    //
    // Asserted by height rather than by position because the total is exactly
    // the sum of the visible parts -- anything painted behind the card would
    // make it taller.
    await tester.pumpWidget(_wrap(_cards()));
    await tester.pump();

    expect(
      tester.getSize(find.byType(HomeCarousel)).height,
      HomeCarousel.cardHeight +
          HomeCarousel.dotsGap +
          HomeCarousel.dotsHeight +
          SparkSpacing.section,
    );
    expect(
      tester.getSize(find.byType(PageView)).height,
      HomeCarousel.cardHeight,
    );
  });

  testWidgets('the card is flat, with no shadow or extra sheets', (tester) async {
    // Regression, reported three times: decoration around this card shows up as
    // a stray band under it or a grey halo at its rounded corners. The PageView
    // clips to a rectangle, so anything drawn outside the card gets cut off with
    // a straight edge. The card must stay flat.
    await tester.pumpWidget(_wrap(_cards()));
    await tester.pump();

    final containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(Container),
      ),
    );
    expect(containers, isNotEmpty);

    for (final container in containers) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration) continue;
      expect(
        decoration.boxShadow,
        isNull,
        reason: 'the card must not cast a shadow inside the clipped viewport',
      );
      expect(decoration.border, isNull, reason: 'and must not draw an outline');
    }
  });

  testWidgets('the card carries no like button', (tester) async {
    await tester.pumpWidget(_wrap(_cards()));
    await tester.pump();
    expect(find.byType(IconButton), findsNothing);
  });
}
