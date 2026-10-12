// Widget check for the online sections of the search screen.
//
//   flutter test test/search_online_widget_test.dart
//
// The phone cannot be driven while locked, so this pins down what actually
// needed proving: that the reworked sliver layout builds, that both streaming
// providers render under their own headings, and that a row tap hands a
// network-backed Song to the player.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/features/search/search_screen.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/services/audius_service.dart';
import 'package:spark/services/jamendo_service.dart';

class _FakeAudiusService extends AudiusService {
  int trendingCalls = 0;
  String? lastQuery;

  @override
  Future<List<AudiusTrack>> trending({
    int limit = 25,
    int offset = 0,
    String? genre,
  }) async {
    trendingCalls++;
    return const [
      AudiusTrack(
        id: 'tr1',
        title: 'Trending One',
        artist: 'Artist A',
        duration: Duration(seconds: 200),
      ),
      AudiusTrack(
        id: 'tr2',
        title: 'Trending Two',
        artist: 'Artist B',
        duration: Duration(seconds: 61),
        artworkUrl: 'https://example.test/cover.jpg',
      ),
    ];
  }

  @override
  Future<List<AudiusTrack>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    lastQuery = query;
    return const [
      AudiusTrack(
        id: 'sr1',
        title: 'Searched Track',
        artist: 'Artist C',
        duration: Duration(seconds: 95),
      ),
    ];
  }
}

class _FakeJamendoService extends JamendoService {
  _FakeJamendoService() : super(clientId: 'test-client-id');

  @override
  Future<List<JamendoTrack>> trending({
    int limit = 25,
    int offset = 0,
    String? tag,
  }) async => const [];

  @override
  Future<List<JamendoTrack>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    return const [
      JamendoTrack(
        id: 'j1',
        title: 'Jamendo Track',
        artist: 'Jamendo Artist',
        duration: Duration(seconds: 180),
        audioUrl: 'https://prod-1.storage.jamendo.com/?trackid=1',
      ),
    ];
  }
}

Widget _wrap(_FakeAudiusService audius, _FakeJamendoService jamendo) {
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
  // The online groups sit below the local one, and slivers build lazily. The
  // default 800x600 test surface would leave them unbuilt, so assertions would
  // fail for a layout reason rather than a behaviour one.
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

  testWidgets('renders trending tracks from both providers', (tester) async {
    final audius = _FakeAudiusService();
    await tester.pumpWidget(_wrap(audius, _FakeJamendoService()));
    await tester.pumpAndSettle();

    expect(audius.trendingCalls, 1);
    expect(find.text('Discover online'), findsOneWidget);
    expect(find.text('Trending One'), findsOneWidget);
    expect(find.text('Trending Two'), findsOneWidget);
    expect(find.text('Artist A'), findsOneWidget);
    // A short track must format as m:ss rather than raw seconds.
    expect(find.text('1:01'), findsOneWidget);
    // Jamendo is configured, so its (empty) section still gets a heading.
    expect(find.text('From Jamendo'), findsOneWidget);
  });

  testWidgets('typing switches both sections to search results', (tester) async {
    final audius = _FakeAudiusService();
    await tester.pumpWidget(_wrap(audius, _FakeJamendoService()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'lofi');
    await tester.pumpAndSettle();

    expect(audius.lastQuery, 'lofi');
    expect(find.text('Searched Track'), findsOneWidget);
    expect(find.text('Jamendo Track'), findsOneWidget);
    // The local group must still be present alongside the online ones.
    expect(find.text('In your library'), findsOneWidget);
  });

  testWidgets('online rows build network-backed Songs', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAudiusService(), _FakeJamendoService()));
    await tester.pumpAndSettle();

    final audiusSong = const AudiusTrack(
      id: 'tr1',
      title: 'Trending One',
      artist: 'Artist A',
      duration: Duration(seconds: 200),
    ).toSong();
    expect(audiusSong.isNetworkSource, isTrue);
    expect(audiusSong.filePath, contains('/stream'));
    expect(audiusSong.id, 'audius:tr1');

    const jamendoTrack = JamendoTrack(
      id: 'j1',
      title: 'Jamendo Track',
      artist: 'Jamendo Artist',
      duration: Duration(seconds: 180),
      audioUrl: 'https://prod-1.storage.jamendo.com/?trackid=1',
    );
    final jamendoSong = jamendoTrack.toSong();
    expect(jamendoSong.isNetworkSource, isTrue);
    expect(jamendoSong.id, 'jamendo:j1');
    expect(jamendoSong.filePath, jamendoTrack.audioUrl);
  });
}
