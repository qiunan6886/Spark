import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/dev_log.dart';
import '../models/song.dart';

/// A track from the Jamendo v3.0 API.
class JamendoTrack {
  const JamendoTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.audioUrl,
    this.album,
    this.artworkUrl,
    this.licenseUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final String? artworkUrl;

  /// Signed stream URL, taken straight from the API response.
  ///
  /// Unlike Audius there is no need to re-resolve it per play: the `from`
  /// parameter carries no timestamp, and a URL generated minutes earlier still
  /// served audio in testing. If Jamendo ever starts enforcing expiry, a fresh
  /// search is what refreshes it.
  final String audioUrl;

  /// Per-track Creative Commons deed. Many Jamendo tracks are BY-NC-*, so this
  /// is what a commercial build would need to inspect.
  final String? licenseUrl;

  Song toSong() => Song(
    id: 'jamendo:$id',
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    fileType: 'MP3',
    albumArt: artworkUrl,
    filePath: audioUrl,
    isExternal: true,
    sourceType: 'jamendo',
    remoteId: id,
    dateAdded: DateTime.now(),
  );
}

/// Read-only client for the Jamendo v3.0 public API.
///
/// The free (non-commercial) tier covers the whole catalogue at up to 35,000
/// requests per month. Only the Client ID is needed -- the Client Secret is for
/// OAuth user sign-in, which this app does not do, so it is deliberately not
/// part of the codebase.
class JamendoService {
  JamendoService({required this.clientId});

  final String clientId;

  static const String _baseUrl = 'https://api.jamendo.com/v3.0';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const int _maxCacheEntries = 40;

  static final http.Client _client = http.Client();
  static final Map<String, List<JamendoTrack>> _cache = {};

  bool get isConfigured => clientId.trim().isNotEmpty;

  /// Most-listened tracks across the catalogue, optionally within [tag].
  Future<List<JamendoTrack>> trending({
    int limit = 25,
    int offset = 0,
    String? tag,
  }) {
    return _fetch(
      'trending|$limit|$offset|${tag ?? ''}',
      {
        'limit': '$limit',
        if (offset > 0) 'offset': '$offset',
        'order': 'popularity_total',
        if (tag != null && tag.isNotEmpty) 'tags': tag,
      },
    );
  }

  /// Free-text search over track and artist names.
  Future<List<JamendoTrack>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value(const []);
    return _fetch(
      'search|$limit|$offset|${trimmed.toLowerCase()}',
      {
        'limit': '$limit',
        if (offset > 0) 'offset': '$offset',
        'search': trimmed,
      },
    );
  }

  /// Tracks carrying [tag] (jamendo's tag vocabulary: rock, electronic, jazz...).
  Future<List<JamendoTrack>> byTag(String tag, {int limit = 25}) {
    return _fetch(
      'tag|$limit|${tag.toLowerCase()}',
      {'limit': '$limit', 'tags': tag, 'order': 'popularity_total'},
    );
  }

  Future<List<JamendoTrack>> _fetch(
    String cacheKey,
    Map<String, String> params,
  ) async {
    if (!isConfigured) return const [];

    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(
        queryParameters: {
          'client_id': clientId.trim(),
          'format': 'json',
          // Jamendo returns its own error payload with HTTP 200, so the status
          // has to be read from the body rather than the response code.
          ...params,
        },
      );

      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        devLog('[Jamendo] $cacheKey -> HTTP ${response.statusCode}');
        return const [];
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];

      final headers = body['headers'];
      if (headers is Map && headers['status'] != 'success') {
        devLog('[Jamendo] $cacheKey -> ${headers['error_message']}');
        return const [];
      }

      final results = body['results'];
      if (results is! List) return const [];

      final tracks = <JamendoTrack>[];
      for (final entry in results) {
        if (entry is! Map<String, dynamic>) continue;
        final track = _parse(entry);
        if (track != null) tracks.add(track);
      }

      devLog('[Jamendo] $cacheKey -> ${tracks.length} track(s)');
      // Jamendo rate-limits bursts and answers with an empty list, so an empty
      // result must not be cached as if it were a real "no matches".
      if (tracks.isEmpty) return tracks;

      _cache[cacheKey] = tracks;
      while (_cache.length > _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      return tracks;
    } catch (e) {
      devLog('[Jamendo] $cacheKey failed: $e');
      return const [];
    }
  }

  JamendoTrack? _parse(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['track_id'];
    final id = rawId?.toString();
    if (id == null || id.isEmpty) return null;

    final audio = (json['audio'] as String?)?.trim();
    if (audio == null || !audio.startsWith('http')) return null;

    final title = (json['name'] as String?)?.trim();
    final artist = (json['artist_name'] as String?)?.trim();

    return JamendoTrack(
      id: id,
      title: (title?.isNotEmpty ?? false) ? title! : 'Untitled',
      artist: (artist?.isNotEmpty ?? false) ? artist! : 'Unknown Artist',
      album: (json['album_name'] as String?)?.trim(),
      duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
      artworkUrl: _artwork(json),
      audioUrl: audio,
      licenseUrl: (json['license_ccurl'] as String?)?.trim(),
    );
  }

  String? _artwork(Map<String, dynamic> json) {
    for (final key in const ['image', 'album_image']) {
      final url = (json[key] as String?)?.trim();
      if (url != null && url.startsWith('http')) return url;
    }
    return null;
  }
}
