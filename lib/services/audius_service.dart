import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/dev_log.dart';
import '../models/song.dart';

/// A track from the Audius public API.
class AudiusTrack {
  const AudiusTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.genre,
    this.artworkUrl,
  });

  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final String? genre;
  final String? artworkUrl;

  /// Converts to the app's [Song] model.
  ///
  /// [Song.filePath] is set to the API's stream *endpoint* rather than a
  /// resolved CDN URL. Audius signs its CDN links with a ~5 minute expiry, so
  /// resolving one and storing it would hand the player a dead link on the next
  /// play; the endpoint re-signs and redirects on every request, which the
  /// player follows transparently.
  Song toSong() => Song(
    id: 'audius:$id',
    title: title,
    artist: artist,
    duration: duration,
    fileType: 'MP3',
    albumArt: artworkUrl,
    genre: genre,
    filePath: AudiusService.streamEndpoint(id),
    isExternal: true,
    sourceType: 'audius',
    remoteId: id,
    dateAdded: DateTime.now(),
  );
}

/// Read-only client for the Audius public API.
///
/// No API key or SDK is involved: plain HTTPS + JSON returning a direct audio
/// URL. Verified reachable from mainland China (450-680 KB/s on a phone).
class AudiusService {
  /// Audius asks clients to identify themselves; this is what gets rate-limited.
  static const String appName = 'Spark';

  static const String _baseUrl = 'https://api.audius.co/v1';
  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Small FIFO cache so switching back to a previous query is instant and does
  /// not spend another request against the shared rate limit.
  static const int _maxCacheEntries = 40;

  static final http.Client _client = http.Client();
  static final Map<String, List<AudiusTrack>> _cache = {};

  /// Stream endpoint for a track. Answers 302 to a freshly signed CDN URL.
  static String streamEndpoint(String trackId) =>
      '$_baseUrl/tracks/$trackId/stream?app_name=$appName';

  Future<List<AudiusTrack>> trending({
    int limit = 25,
    int offset = 0,
    String? genre,
  }) {
    return _cached('trending|$limit|$offset|${genre ?? ''}', () {
      final uri = Uri.parse('$_baseUrl/tracks/trending').replace(
        queryParameters: {
          'app_name': appName,
          'limit': '$limit',
          if (offset > 0) 'offset': '$offset',
          if (genre != null && genre.isNotEmpty) 'genre': genre,
        },
      );
      return _fetchTracks(uri);
    });
  }

  Future<List<AudiusTrack>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value(const []);
    return _cached('search|$limit|$offset|${trimmed.toLowerCase()}', () {
      final uri = Uri.parse('$_baseUrl/tracks/search').replace(
        queryParameters: {
          'app_name': appName,
          'query': trimmed,
          'limit': '$limit',
          if (offset > 0) 'offset': '$offset',
        },
      );
      return _fetchTracks(uri);
    });
  }

  Future<List<AudiusTrack>> _cached(
    String key,
    Future<List<AudiusTrack>> Function() load,
  ) async {
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = await load();
    // Do not cache a failure: a transient timeout should not become permanent
    // for the rest of the session.
    if (result.isEmpty) return result;

    _cache[key] = result;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return result;
  }

  Future<List<AudiusTrack>> _fetchTracks(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        devLog('[Audius] ${uri.path} -> HTTP ${response.statusCode}');
        return const [];
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];
      final data = body['data'];
      if (data is! List) return const [];

      final tracks = <AudiusTrack>[];
      for (final entry in data) {
        if (entry is! Map<String, dynamic>) continue;
        final track = _parse(entry);
        if (track != null) tracks.add(track);
      }
      devLog('[Audius] ${uri.path} -> ${tracks.length} track(s)');
      return tracks;
    } catch (e) {
      // Offline, blocked, or rate-limited. The UI shows an empty online section
      // rather than an error, because local playback is unaffected.
      devLog('[Audius] ${uri.path} failed: $e');
      return const [];
    }
  }

  AudiusTrack? _parse(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    if (json['is_streamable'] == false) return null;
    if (json['is_available'] == false) return null;

    final title = (json['title'] as String?)?.trim();
    final user = json['user'];
    final userName = user is Map<String, dynamic>
        ? (user['name'] as String?)?.trim()
        : null;

    return AudiusTrack(
      id: id,
      title: (title?.isNotEmpty ?? false) ? title! : 'Untitled',
      artist: (userName?.isNotEmpty ?? false) ? userName! : 'Unknown Artist',
      duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
      genre: (json['genre'] as String?)?.trim(),
      artworkUrl: _bestArtwork(json['artwork']),
    );
  }

  /// Picks a mid-size cover: 480px is plenty for a list row and the player disc.
  String? _bestArtwork(Object? artwork) {
    if (artwork is! Map) return null;
    for (final size in const ['480x480', '1000x1000', '150x150']) {
      final url = artwork[size];
      if (url is String && url.startsWith('http')) return url;
    }
    return null;
  }
}
