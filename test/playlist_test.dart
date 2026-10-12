// Round-trip checks for user playlists, plus the reorder index conversion.
//
//   flutter test test/playlist_test.dart
//
// Reordering is the part worth pinning down: ReorderableListView's modern
// callback and PlaylistService.reorderSongs each apply the "removed item"
// adjustment, so getting the conversion wrong shifts every downward drag by one
// slot -- a bug that looks like random misbehaviour rather than a crash.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark/features/library/playlist_detail_screen.dart';
import 'package:spark/services/playlist_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaylistService.instance = PlaylistService();
  });

  group('playlist CRUD', () {
    test('creates, fills, reorders, removes and deletes', () async {
      final service = PlaylistService.instance;
      final playlist = await service.createPlaylist('Road trip');
      expect(playlist, isNotNull);
      final id = playlist!.id;

      for (final songId in ['a', 'b', 'c']) {
        expect(await service.addSongToPlaylist(id, songId), isTrue);
      }
      expect((await service.getPlaylist(id))!.songIds, ['a', 'b', 'c']);

      // Drag 'a' from the front to the very end.
      await service.reorderSongs(id, 0, rawReorderIndex(0, 2));
      expect((await service.getPlaylist(id))!.songIds, ['b', 'c', 'a']);

      // Drag it back to the front.
      await service.reorderSongs(id, 2, rawReorderIndex(2, 0));
      expect((await service.getPlaylist(id))!.songIds, ['a', 'b', 'c']);

      // One step down.
      await service.reorderSongs(id, 0, rawReorderIndex(0, 1));
      expect((await service.getPlaylist(id))!.songIds, ['b', 'a', 'c']);

      await service.removeSongFromPlaylist(id, 'a');
      expect((await service.getPlaylist(id))!.songIds, ['b', 'c']);

      expect(await service.deletePlaylist(id), isTrue);
      expect(await service.getPlaylists(), isEmpty);
    });

    test('rejects an empty name and duplicate adds', () async {
      final service = PlaylistService.instance;
      expect(await service.createPlaylist('   '), isNull);

      final playlist = await service.createPlaylist('Set');
      final id = playlist!.id;
      expect(await service.addSongToPlaylist(id, 'x'), isTrue);
      // Adding the same song twice must not duplicate the entry.
      await service.addSongToPlaylist(id, 'x');
      expect((await service.getPlaylist(id))!.songIds, ['x']);
    });

    test('renames and survives a reload', () async {
      final service = PlaylistService.instance;
      final playlist = await service.createPlaylist('Old name');
      final id = playlist!.id;
      await service.addSongToPlaylist(id, 'a');

      await service.updatePlaylist(
        (await service.getPlaylist(id))!.copyWith(name: 'New name'),
      );

      // A fresh instance reads back from prefs, which is what a relaunch does.
      final reloaded = PlaylistService();
      final stored = await reloaded.getPlaylist(id);
      expect(stored, isNotNull);
      expect(stored!.name, 'New name');
      expect(stored.songIds, ['a']);
    });

    test('unknown playlist ids are handled', () async {
      final service = PlaylistService.instance;
      expect(await service.getPlaylist('nope'), isNull);
      expect(await service.deletePlaylist('nope'), isFalse);
      expect(await service.addSongToPlaylist('nope', 'x'), isFalse);
      expect(await service.removeSongFromPlaylist('nope', 'x'), isFalse);
    });

    test('bulk add appends in order and skips duplicates', () async {
      final service = PlaylistService.instance;
      final id = (await service.createPlaylist('Bulk'))!.id;

      expect(
        await service.addSongsToPlaylist(id, ['a', 'b', 'c']),
        isTrue,
      );
      expect((await service.getPlaylist(id))!.songIds, ['a', 'b', 'c']);

      // Re-adding an existing id, plus a new one, appends only the new one and
      // keeps the original positions.
      await service.addSongsToPlaylist(id, ['b', 'd', 'a', 'e']);
      expect((await service.getPlaylist(id))!.songIds, [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
    });

    test('bulk add handles empty and duplicate-only input', () async {
      final service = PlaylistService.instance;
      final id = (await service.createPlaylist('Noop'))!.id;

      expect(await service.addSongsToPlaylist(id, []), isTrue);
      expect((await service.getPlaylist(id))!.songIds, isEmpty);

      await service.addSongsToPlaylist(id, ['x']);
      final updatedAt = (await service.getPlaylist(id))!.updatedAt;
      // Adding only what is already there must not touch the playlist.
      expect(await service.addSongsToPlaylist(id, ['x', 'x']), isTrue);
      expect((await service.getPlaylist(id))!.updatedAt, updatedAt);
      expect((await service.getPlaylist(id))!.songIds, ['x']);
    });

    test('bulk add reports a missing playlist', () async {
      final service = PlaylistService.instance;
      expect(await service.addSongsToPlaylist('nope', ['a']), isFalse);
    });
  });

  group('rawReorderIndex', () {
    test('undoes the removal adjustment for downward drags', () {
      // The framework reports the post-removal slot, so a move to the end of a
      // 3-item list arrives as (0, 2) and must be handed on as 3.
      expect(rawReorderIndex(0, 2), 3);
      expect(rawReorderIndex(0, 1), 2);
    });

    test('leaves upward drags alone', () {
      expect(rawReorderIndex(2, 0), 0);
      expect(rawReorderIndex(1, 0), 0);
    });

    test('a no-op drag stays a no-op', () {
      expect(rawReorderIndex(1, 1), 1);
    });
  });
}
