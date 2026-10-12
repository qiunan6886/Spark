// Checks for favourites, in particular streamed (non-library) tracks.
//
//   flutter test test/favorites_test.dart
//
// The bug this pins down: the provider used to derive its id set from
// `getFavorites()`, which resolves ids against the library. A streamed track has
// no library row, so it was dropped -- storing the favourite but never lighting
// the heart or listing it in Liked.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark/models/song.dart';
import 'package:spark/services/favorites_service.dart';

Song _streamed() => Song(
  id: 'audius:abc',
  title: 'Streamed Track',
  artist: 'Streaming Artist',
  duration: const Duration(seconds: 200),
  fileType: 'MP3',
  filePath: 'https://api.audius.co/v1/tracks/abc/stream',
  isExternal: true,
  sourceType: 'audius',
  remoteId: 'abc',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a streamed favourite keeps its id', () async {
    final service = FavoritesService();
    await service.addFavorite('audius:abc', song: _streamed());

    final ids = await service.getFavoriteIds();
    expect(
      ids,
      contains('audius:abc'),
      reason: 'the id is the source of truth for "is it favourited"',
    );
    expect(await service.isFavorite('audius:abc'), isTrue);
  });

  test('the id survives a reload', () async {
    await FavoritesService().addFavorite('audius:abc', song: _streamed());

    // A fresh instance reads from prefs, which is what a relaunch does.
    final reloaded = FavoritesService();
    expect(await reloaded.getFavoriteIds(), contains('audius:abc'));
    expect(await reloaded.isFavorite('audius:abc'), isTrue);
  });

  test('toggling a streamed favourite off removes it', () async {
    final service = FavoritesService();
    final song = _streamed();

    expect(await service.toggleFavorite(song.id, song: song), isTrue);
    expect(await service.getFavoriteIds(), contains(song.id));

    expect(await service.toggleFavorite(song.id, song: song), isFalse);
    expect(await service.getFavoriteIds(), isNot(contains(song.id)));
  });

  test('removing one of several drops only that id', () async {
    final service = FavoritesService();
    await service.addFavorites(['audius:a', 'audius:b', 'audius:c']);
    await service.removeFavorite('audius:b');

    expect(
      await service.getFavoriteIds(),
      {'audius:a', 'audius:c'},
    );
  });

  test('bulk removal and clearing work', () async {
    final service = FavoritesService();
    await service.addFavorites(['x', 'y', 'z']);
    await service.removeFavorites(['x', 'z']);
    expect(await service.getFavoriteIds(), {'y'});

    await service.clearFavorites();
    expect(await service.getFavoriteIds(), isEmpty);
  });

  test('a corrupt external blob does not break loading ids', () async {
    SharedPreferences.setMockInitialValues({
      'favorite_song_ids': ['audius:abc'],
      'favorite_external_songs': 'not json at all',
    });

    final service = FavoritesService();
    expect(await service.getFavoriteIds(), contains('audius:abc'));
  });
}
