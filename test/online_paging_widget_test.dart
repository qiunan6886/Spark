// Widget check for automatic paging on the online feeds.
//
//   flutter test test/online_paging_widget_test.dart
//
// Two paths matter and they are easy to get wrong in opposite directions:
// scrolling near the end must fetch the next page, and a list too short to
// scroll must still fill itself.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/features/search/search_screen.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/services/audius_service.dart';
import 'package:spark/services/jamendo_service.dart';

/// Serves `totalPages` full pages and then an empty one.
class _PagingAudiusService extends AudiusService {
  _PagingAudiusService({this.totalPages = 6});

  final int totalPages;
  final List<int> requestedOffsets = [];

  @override
  Future<List<AudiusTrack>> trending({
    int limit = 25,
    int offset = 0,
    String? genre,
  }) async {
    requestedOffsets.add(offset);
    if (offset >= totalPages * PagedFeedSize.value) return const [];
    return List.generate(
      limit,
      (i) => AudiusTrack(
        id: 'p${offset + i}',
        title: 'Track ${offset + i}',
        artist: 'Artist',
        duration: Duration(seconds: 100 + (i % 60)),
      ),
    );
  }

  @override
  Future<List<AudiusTrack>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async => const [];
}

/// Mirrors PagedFeed.pageSize, which the test needs but the widget layer does
/// not otherwise expose.
abstract final class PagedFeedSize {
  static const int value = 30;
}

class _EmptyJamendoService extends JamendoService {
  _EmptyJamendoService() : super(clientId: 'test');
}

/// One short page, so nothing should ever page further.
class _ShortAudiusService extends AudiusService {
  final List<int> requestedOffsets = [];

  @override
  Future<List<AudiusTrack>> trending({
    int limit = 25,
    int offset = 0,
    String? genre,
  }) async {
    requestedOffsets.add(offset);
    return const [
      AudiusTrack(
        id: 'one',
        title: 'Only one',
        artist: 'Solo',
        duration: Duration(seconds: 120),
      ),
    ];
  }

  @override
  Future<List<AudiusTrack>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async => const [];
}

Widget _wrap(AudiusService audius, JamendoService jamendo) {
  return ProviderScope(
    overrides: [
      audiusServiceProvider.overrideWithValue(audius),
      jamendoServiceProvider.overrideWithValue(jamendo),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: SearchScreen(),
    ),
  );
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('fills a short list without any scrolling', (tester) async {
    final audius = _PagingAudiusService();
    await tester.pumpWidget(_wrap(audius, _EmptyJamendoService()));
    await tester.pumpAndSettle();

    // 30 rows do not fill a 2400px viewport, so follow-up pages must arrive on
    // their own: with no overflow there is nothing for the user to scroll.
    expect(audius.requestedOffsets.first, 0);
    expect(
      audius.requestedOffsets.length,
      greaterThan(1),
      reason: 'a list shorter than the viewport must keep paging',
    );
  });

  testWidgets('scrolling near the end fetches the next page', (tester) async {
    final audius = _PagingAudiusService();
    await tester.pumpWidget(_wrap(audius, _EmptyJamendoService()));
    await tester.pumpAndSettle();

    final beforeScroll = audius.requestedOffsets.length;
    final lastOffset = audius.requestedOffsets.last;

    // Drag well past the trigger distance.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pumpAndSettle();

    expect(
      audius.requestedOffsets.length,
      greaterThan(beforeScroll),
      reason: 'reaching the end of the list must fetch another page',
    );
    expect(audius.requestedOffsets.last, greaterThan(lastOffset));
  });

  testWidgets('a short first page stops paging for good', (tester) async {
    final audius = _ShortAudiusService();
    await tester.pumpWidget(_wrap(audius, _EmptyJamendoService()));
    await tester.pumpAndSettle();

    expect(find.text('Only one'), findsOneWidget);
    // A short page means the catalogue ended; asking again would be wasted
    // requests against a limited monthly quota.
    expect(audius.requestedOffsets, [0]);
  });
}
