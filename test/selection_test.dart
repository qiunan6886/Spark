// Checks for the multi-select list and the swipe action wrapper.
//
//   flutter test test/selection_test.dart
//
// These two widgets carry every list in the app, so a mistake here is a mistake
// everywhere: a long-press that does not enter selection, an action that runs on
// the wrong songs, or swipe gestures still live underneath a selection.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/models/song.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/providers/sleep_timer_provider.dart';
import 'package:spark/widgets/selectable_song_list.dart';
import 'package:spark/widgets/swipe_actions.dart';

Song _song(int i) => Song(
  id: 's$i',
  title: 'Track $i',
  artist: 'Artist $i',
  duration: const Duration(seconds: 180),
  fileType: 'MP3',
  filePath: '/music/$i.mp3',
);

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('SelectableSongList', () {
    late List<Song> library;
    late List<List<Song>> actionCalls;
    late List<Song> played;

    setUp(() {
      library = [for (var i = 0; i < 4; i++) _song(i)];
      actionCalls = [];
      played = [];
    });

    Widget build() {
      return _wrap(
        SelectableSongList(
          songs: library,
          onPlay: (song, queue) => played.add(song),
          swipeActionsFor: (_) => const [],
          selectionActions: [
            SelectionAction(
              icon: Icons.playlist_add,
              label: 'Add',
              onPressed: actionCalls.add,
            ),
          ],
        ),
      );
    }

    testWidgets('starts in normal mode', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(find.text('Track 0'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
      expect(find.text('Select all'), findsNothing);
    });

    testWidgets('long-press enters selection mode', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Track 1'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
      // The row count is unchanged; the bar is additive.
      expect(find.text('Track 0'), findsOneWidget);
    });

    testWidgets('tapping in selection mode picks rather than plays', (
      tester,
    ) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Track 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track 2'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
      expect(
        played,
        isEmpty,
        reason: 'a tap while selecting must not start playback',
      );
    });

    testWidgets('an action receives the picked songs in list order', (
      tester,
    ) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Pick out of order, to prove the payload follows the list.
      await tester.longPress(find.text('Track 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.playlist_add));
      await tester.pumpAndSettle();

      expect(actionCalls, hasLength(1));
      expect(
        actionCalls.single.map((s) => s.id).toList(),
        ['s1', 's3'],
      );
      // Running an action leaves selection mode.
      expect(find.text('2 selected'), findsNothing);
    });

    testWidgets('select all and deselect all toggle', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Track 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(find.text('4 selected'), findsOneWidget);
      expect(find.text('Deselect all'), findsOneWidget);

      await tester.tap(find.text('Deselect all'));
      await tester.pumpAndSettle();

      // Deselecting everything leaves selection mode entirely.
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('cancel leaves selection mode', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Track 0'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsNothing);
    });

    testWidgets('the bar clears the floating mini player and nav bar', (
      tester,
    ) async {
      // Regression: the shell uses extendBody with the mini player and nav bar
      // painted over the content, so a bar flush with the bottom was rendered
      // underneath them and never seen.
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Track 0'));
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.text('1 selected'));
      final viewportBottom = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      expect(
        viewportBottom - bar.bottom,
        greaterThanOrEqualTo(kFloatingChromeHeight * 0.8),
        reason: 'the selection bar must sit above the floating chrome',
      );
    });

    testWidgets('tapping normally still plays', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Track 2'));
      await tester.pumpAndSettle();

      expect(played.map((s) => s.id).toList(), ['s2']);
    });

    testWidgets('shows the empty state when there is nothing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SelectableSongList(
            songs: [],
            onPlay: _noopPlay,
            swipeActionsFor: _noSwipe,
            selectionActions: [],
            emptyState: Text('nothing here'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('nothing here'), findsOneWidget);
    });
  });

  group('shrinkWrap mode', () {
    testWidgets('lays out inside an unbounded-height parent', (tester) async {
      // Regression: inside a sliver there is no height to expand into, and the
      // internal Expanded threw "non-zero flex but incoming height constraints
      // are unbounded". The search tab puts this widget in a SliverToBoxAdapter.
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: SelectableSongList(
              songs: [for (var i = 0; i < 3; i++) _song(i)],
              shrinkWrap: true,
              onPlay: _noopPlay,
              swipeActionsFor: _noSwipe,
              selectionActions: [
                SelectionAction(
                  icon: Icons.playlist_add,
                  label: 'Add',
                  onPressed: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track 0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Selection still works in this mode.
      await tester.longPress(find.text('Track 1'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the selection bar keeps every action visible', () {
    testWidgets('both actions survive a long label on a narrow screen', (
      tester,
    ) async {
      // Regression: the count label plus "select all" plus the actions is a
      // fixed-width row. On a narrow phone a long label pushed the trailing
      // actions off, which is how the search tab lost its download button.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          SelectableSongList(
            songs: [for (var i = 0; i < 20; i++) _song(i)],
            onPlay: _noopPlay,
            swipeActionsFor: _noSwipe,
            selectionActions: [
              SelectionAction(
                icon: Icons.download,
                label: 'Download',
                onPressed: (_) {},
              ),
              SelectionAction(
                icon: Icons.delete,
                label: 'Remove download',
                destructive: true,
                onPressed: (_) {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Track 0'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the bar must not overflow',
      );

      // The action still fires with the picked songs.
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsNothing);
    });
  });

  group('SwipeActions', () {
    testWidgets('renders the child untouched when there are no actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SwipeActions(
            actions: [],
            child: Text('row'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('row'), findsOneWidget);
    });

    testWidgets('reveals an action on left-swipe and fires it', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            actions: [
              SwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                onPressed: () => fired++,
              ),
            ],
            child: const SizedBox(height: 72, child: Text('row')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag the row leftwards to open the end pane.
      await tester.drag(find.text('row'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('is inert when disabled', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            enabled: false,
            actions: [
              SwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                onPressed: () => fired++,
              ),
            ],
            child: const SizedBox(height: 72, child: Text('row')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('row'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsNothing);
      expect(fired, 0);
    });
  });

  group('formatCountdown', () {
    test('formats minutes and seconds', () {
      expect(formatCountdown(const Duration(minutes: 30)), '30:00');
      expect(formatCountdown(const Duration(minutes: 5, seconds: 7)), '5:07');
      expect(formatCountdown(const Duration(seconds: 59)), '0:59');
      expect(formatCountdown(const Duration(minutes: 90)), '90:00');
    });
  });
}

void _noopPlay(Song song, List<Song> queue) {}
List<SwipeAction> _noSwipe(Song song) => const [];
