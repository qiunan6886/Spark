import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark/models/song.dart';
import 'package:spark/data/repositories/song_repository.dart';

/// Service for managing favorite songs.
/// Stores favorite song IDs in SharedPreferences for persistence.
class FavoritesService {
  static const String _favoritesKey = 'favorite_song_ids';

  /// Stored details for favourited tracks that are not in the library -- i.e.
  /// streamed ones.
  ///
  /// The id alone is not enough for those: `getFavorites()` resolves ids against
  /// the library, so a streamed favourite would be stored but never resolvable.
  /// The heart would stay empty and the track would never show up in Liked.
  static const String _externalKey = 'favorite_external_songs';

  final SongRepository? _injectedRepository;

  // Cached set of favorite IDs for quick lookup
  Set<String> _favoriteIds = {};
  final Map<String, Map<String, dynamic>> _externalSongs = {};
  bool _isLoaded = false;

  FavoritesService({SongRepository? songRepository})
    : _injectedRepository = songRepository;

  /// Built on first use.
  ///
  /// The repository needs the database, but answering "is this id favourited"
  /// does not -- and constructing it eagerly made the service unusable anywhere
  /// the database is not open.
  SongRepository get _songRepository =>
      _injectedRepository ?? SongRepository();

  /// Load favorites from SharedPreferences.
  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favoritesKey) ?? [];
    _favoriteIds = ids.toSet();

    final external = prefs.getString(_externalKey);
    if (external != null) {
      try {
        final decoded = jsonDecode(external);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map<String, dynamic>) {
              _externalSongs[entry.key as String] =
                  entry.value as Map<String, dynamic>;
            }
          }
        }
      } catch (_) {
        // A corrupt blob is not worth failing startup over; the ids above are
        // the source of truth for "is it favourited".
        _externalSongs.clear();
      }
    }

    _isLoaded = true;
  }

  /// The raw stored ids, including streamed tracks.
  ///
  /// Distinct from `getFavorites().map((s) => s.id)`, which only yields ids that
  /// resolve inside the library.
  Future<Set<String>> getFavoriteIds() async {
    await _ensureLoaded();
    return Set.unmodifiable(_favoriteIds);
  }

  /// Get all favorite songs.
  ///
  /// Library tracks first, then streamed ones that carry a stored record.
  Future<List<Song>> getFavorites() async {
    await _ensureLoaded();

    if (_favoriteIds.isEmpty) return [];

    final allSongs = await _songRepository.getAllSongs();
    final libraryFavourites = allSongs
        .where((song) => _favoriteIds.contains(song.id))
        .toList();

    final resolvedIds = {for (final song in libraryFavourites) song.id};
    final external = <Song>[
      for (final id in _favoriteIds)
        if (!resolvedIds.contains(id)) ?_songFromJson(_externalSongs[id]),
    ];

    return [...libraryFavourites, ...external];
  }

  /// Check if a song is a favorite.
  Future<bool> isFavorite(String songId) async {
    await _ensureLoaded();
    return _favoriteIds.contains(songId);
  }

  /// Add a song to favorites.
  ///
  /// Pass [song] when it may not be in the library (a streamed track): its
  /// details are then stored alongside the id so it can be listed later.
  Future<void> addFavorite(String songId, {Song? song}) async {
    await _ensureLoaded();

    _favoriteIds.add(songId);
    _rememberExternal(songId, song);
    await _saveFavorites();
  }

  /// Remove a song from favorites.
  Future<void> removeFavorite(String songId) async {
    await _ensureLoaded();

    _favoriteIds.remove(songId);
    _externalSongs.remove(songId);
    await _saveFavorites();
  }

  /// Adds several favourites with a single save.
  ///
  /// A multi-select of a few hundred tracks otherwise rewrites the stored list
  /// once per track.
  Future<void> addFavorites(Iterable<String> songIds) async {
    await _ensureLoaded();

    var changed = false;
    for (final id in songIds) {
      if (_favoriteIds.add(id)) changed = true;
    }
    if (changed) await _saveFavorites();
  }

  /// Removes several favourites with a single save.
  Future<void> removeFavorites(Iterable<String> songIds) async {
    await _ensureLoaded();

    var changed = false;
    for (final id in songIds) {
      if (_favoriteIds.remove(id)) changed = true;
      _externalSongs.remove(id);
    }
    if (changed) await _saveFavorites();
  }

  /// Toggle favorite status for a song.
  /// Returns true if the song is now a favorite, false otherwise.
  ///
  /// Pass [song] for a streamed track so its details can be stored.
  Future<bool> toggleFavorite(String songId, {Song? song}) async {
    await _ensureLoaded();

    if (_favoriteIds.contains(songId)) {
      _favoriteIds.remove(songId);
      _externalSongs.remove(songId);
      await _saveFavorites();
      return false;
    } else {
      _favoriteIds.add(songId);
      _rememberExternal(songId, song);
      await _saveFavorites();
      return true;
    }
  }

  /// Get the count of favorite songs.
  Future<int> getFavoritesCount() async {
    await _ensureLoaded();
    return _favoriteIds.length;
  }

  /// Save favorites to SharedPreferences.
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
    if (_externalSongs.isEmpty) {
      await prefs.remove(_externalKey);
    } else {
      await prefs.setString(_externalKey, jsonEncode(_externalSongs));
    }
  }

  /// Stores enough about [song] to rebuild it when it is not in the library.
  void _rememberExternal(String songId, Song? song) {
    if (song == null || !song.isNetworkSource) return;
    _externalSongs[songId] = {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'durationMs': song.duration.inMilliseconds,
      'fileType': song.fileType,
      'albumArt': song.albumArt,
      'genre': song.genre,
      'filePath': song.filePath,
      'sourceType': song.sourceType,
      'remoteId': song.remoteId,
    };
  }

  Song? _songFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return Song(
      id: id,
      title: (json['title'] as String?) ?? 'Unknown',
      artist: (json['artist'] as String?) ?? '',
      album: json['album'] as String?,
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      fileType: (json['fileType'] as String?) ?? 'MP3',
      albumArt: json['albumArt'] as String?,
      genre: json['genre'] as String?,
      filePath: json['filePath'] as String?,
      isExternal: true,
      sourceType: json['sourceType'] as String?,
      remoteId: json['remoteId'] as String?,
    );
  }

  /// Clear all favorites.
  Future<void> clearFavorites() async {
    _favoriteIds.clear();
    _externalSongs.clear();
    await _saveFavorites();
  }
}
