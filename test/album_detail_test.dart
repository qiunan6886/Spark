// Checks for the album detail screen.
//
//   flutter test test/album_detail_test.dart
//
// Tapping an album used to start playing it with no way to see the track list.
// The row now opens this screen, so these checks pin down that the songs are
// listed and that the play button offers the whole album.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/data/repositories/song_repository.dart';
import 'package:spark/features/library/album_detail_screen.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/models/song.dart';

Song _song(int i) => Song(
  id: 'a$i',
  title: 'Album Track $i',
  artist: 'The Artist',
  album: 'The Album',
  duration: Duration(seconds: 120 + i),
  fileType: 'MP3',
  filePath: '/music/a$i.mp3',
);

AlbumGroup _album() => AlbumGroup(
  key: 'The Album|The Artist',
  albumName: 'The Album',
  albumArtist: 'The Artist',
  songs: [for (var i = 0; i < 3; i++) _song(i)],
);

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('lists every track on the album', (tester) async {
    await tester.pumpWidget(_wrap(AlbumDetailScreen(album: _album())));
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      expect(
        find.text('Album Track $i'),
        findsOneWidget,
        reason: 'the track list is the point of this screen',
      );
    }
  });

  testWidgets('offers play all, in both places it is useful', (tester) async {
    await tester.pumpWidget(_wrap(AlbumDetailScreen(album: _album())));
    await tester.pump();

    // A header button and the floating action button -- one is reachable
    // without scrolling, the other stays reachable once scrolled down.
    expect(find.text('Play all'), findsNWidgets(2));
  });

  testWidgets('shows the album name in the app bar', (tester) async {
    await tester.pumpWidget(_wrap(AlbumDetailScreen(album: _album())));
    await tester.pump();

    expect(find.text('The Album'), findsWidgets);
  });

  testWidgets('an empty album says so instead of showing a blank page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AlbumDetailScreen(
          album: const AlbumGroup(
            key: 'empty',
            albumName: 'Empty Album',
            albumArtist: '',
            songs: [],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Empty Album'), findsOneWidget);
    expect(find.text('Play all'), findsNothing);
  });
}
