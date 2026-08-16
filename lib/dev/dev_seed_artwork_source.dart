import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';

/// Dev-only boundary used by the reset seeder to obtain and persist matching
/// album artwork without coupling seed data to a specific metadata provider.
abstract interface class DevSeedArtworkSource {
  Future<String?> saveArtworkForAlbum({
    required String artist,
    required String title,
    required int releaseYear,
    required String albumId,
  });

  Future<void> deleteArtwork(String? artworkPath);

  Future<void> close();
}

/// Resolves a MusicBrainz release group and downloads its 500 px front cover
/// from Cover Art Archive, then persists it through ArtworkStorageService.
class MusicBrainzDevSeedArtworkSource implements DevSeedArtworkSource {
  MusicBrainzDevSeedArtworkSource({
    ArtworkStorageService? artworkStorageService,
    HttpClient? client,
  }) : _artworkStorageService =
           artworkStorageService ?? ArtworkStorageService(),
       _client = client ?? HttpClient();

  static const _userAgent =
      'VinylAppDevSeed/1.0 (https://github.com/hunter-goller/vinyl-app)';
  static const _musicBrainzDelay = Duration(milliseconds: 1100);

  final ArtworkStorageService _artworkStorageService;
  final HttpClient _client;
  DateTime? _lastMusicBrainzRequestAt;

  @override
  Future<String?> saveArtworkForAlbum({
    required String artist,
    required String title,
    required int releaseYear,
    required String albumId,
  }) async {
    final releaseGroupId = await _findReleaseGroupId(
      artist: artist,
      title: title,
      releaseYear: releaseYear,
    );
    if (releaseGroupId == null) return null;

    final coverUri = Uri.https(
      'coverartarchive.org',
      '/release-group/$releaseGroupId/front-500',
    );
    final response = await _get(coverUri);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }

    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    if (bytes.isEmpty) return null;

    final tempRoot = await getTemporaryDirectory();
    final tempDirectory = Directory(
      p.join(tempRoot.path, 'vinyl_app_dev_seed_artwork'),
    );
    await tempDirectory.create(recursive: true);
    final source = File(p.join(tempDirectory.path, '$albumId.jpg'));

    try {
      await source.writeAsBytes(bytes, flush: true);
      return await _artworkStorageService.saveArtwork(source, albumId);
    } finally {
      if (await source.exists()) {
        await source.delete();
      }
    }
  }

  @override
  Future<void> deleteArtwork(String? artworkPath) {
    return _artworkStorageService.deleteArtwork(artworkPath);
  }

  Future<String?> _findReleaseGroupId({
    required String artist,
    required String title,
    required int releaseYear,
  }) async {
    await _waitForMusicBrainzRateLimit();

    final query =
        'releasegroup:"${_escapeLucene(title)}" '
        'AND artist:"${_escapeLucene(artist)}" AND primarytype:album';
    final uri = Uri.https('musicbrainz.org', '/ws/2/release-group/', {
      'query': query,
      'fmt': 'json',
      'limit': '8',
    });

    final response = await _get(uri, musicBrainz: true);
    _lastMusicBrainzRequestAt = DateTime.now();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }

    final body = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final groups = decoded['release-groups'];
    if (groups is! List || groups.isEmpty) return null;

    final normalizedTitle = title.trim().toLowerCase();
    Map<String, dynamic>? bestExactYear;
    Map<String, dynamic>? bestExact;
    Map<String, dynamic>? fallback;

    for (final raw in groups) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id'];
      if (id is! String || id.isEmpty) continue;
      fallback ??= raw;

      final candidateTitle = (raw['title'] as String? ?? '')
          .trim()
          .toLowerCase();
      if (candidateTitle != normalizedTitle) continue;
      bestExact ??= raw;

      final firstReleaseDate = raw['first-release-date'] as String?;
      if (firstReleaseDate?.startsWith('$releaseYear') ?? false) {
        bestExactYear = raw;
        break;
      }
    }

    final selected = bestExactYear ?? bestExact ?? fallback;
    return selected?['id'] as String?;
  }

  Future<HttpClientResponse> _get(Uri uri, {bool musicBrainz = false}) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close();

      if (response.statusCode != HttpStatus.serviceUnavailable ||
          attempt == 3) {
        return response;
      }

      await response.drain<void>();
      if (musicBrainz) {
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      } else {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    throw StateError('Unreachable HTTP retry state.');
  }

  Future<void> _waitForMusicBrainzRateLimit() async {
    final previous = _lastMusicBrainzRequestAt;
    if (previous == null) return;

    final elapsed = DateTime.now().difference(previous);
    if (elapsed < _musicBrainzDelay) {
      await Future<void>.delayed(_musicBrainzDelay - elapsed);
    }
  }

  String _escapeLucene(String value) {
    const special = r'+-!(){}[]^"~*?:\\/|&';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      if (special.contains(character)) {
        buffer.write(r'\\');
      }
      buffer.write(character);
    }
    return buffer.toString();
  }

  @override
  Future<void> close() async {
    _client.close(force: true);
  }
}
