import 'dart:typed_data';

import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

/// The backend owns Discogs OAuth and returns normalized metadata.
class DiscogsApiClient {
  const DiscogsApiClient(this.session, this.transport);
  final InstallationSession session;
  final BackendTransport transport;

  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await session.request(method, path, query: query);
    return response.status == 204 ? const {} : response.json();
  }

  Future<DiscogsAccount?> account() async {
    if (!await session.hasSession()) {
      return null;
    }
    final json = await call('GET', '/v1/discogs/account');
    if (json['connected'] == false) {
      return null;
    }
    if (json['connected'] != true ||
        json['discogsId'] is! int ||
        json['username'] is! String) {
      throw const DiscogsApiFailure('The server returned an invalid account.');
    }
    return DiscogsAccount(
      id: json['discogsId'] as int,
      username: json['username'] as String,
    );
  }

  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required String artist,
    required String title,
    int limit = 5,
  }) async {
    final json = await call(
      'GET',
      '/v1/discogs/search',
      query: {
        'artist': artist.trim(),
        'title': title.trim(),
        'page': '1',
        'perPage': limit.clamp(1, 100).toString(),
      },
    );
    return _results(json);
  }

  Future<List<DiscogsReleaseSearchResult>> searchReleasesByBarcode({
    required String barcode,
    int limit = 10,
  }) async {
    final normalized = barcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^[0-9]{8,14}$').hasMatch(normalized)) {
      throw const DiscogsApiFailure('Enter a valid barcode.');
    }
    return _results(
      await call(
        'GET',
        '/v1/discogs/barcode/$normalized',
        query: {'perPage': limit.clamp(1, 100).toString()},
      ),
    );
  }

  List<DiscogsReleaseSearchResult> _results(Map<String, dynamic> json) =>
      _decode(
        () => _rows(json, 'items')
            .map(
              (v) => DiscogsReleaseSearchResult(
                releaseId: v['releaseId'] as int,
                title: v['title'] as String,
                artist: v['artist'] as String,
                year: v['year'] as int?,
                label: v['label'] as String?,
                country: v['country'] as String?,
                formats: _strings(v['formats']),
                coverImageUrl: v['coverImageUrl'] as String?,
              ),
            )
            .toList(growable: false),
      );

  Future<DiscogsReleaseDetails> release({required int releaseId}) async {
    if (releaseId < 1) {
      throw const DiscogsApiFailure('Invalid release.');
    }
    final v = await call('GET', '/v1/discogs/releases/$releaseId');
    return _decode(
      () => DiscogsReleaseDetails(
        releaseId: v['releaseId'] as int,
        title: v['title'] as String,
        artist: v['artist'] as String,
        year: v['year'] as int?,
        label: v['label'] as String?,
        genres: _strings(v['genres']),
        styles: _strings(v['styles']),
        artworkUrl: v['artworkUrl'] as String?,
        tracks: _rows(v, 'tracks')
            .map(
              (t) => DiscogsTrack(
                title: t['title'] as String,
                sequence: t['sequence'] as int,
                position: t['position'] as String?,
                side: t['side'] as String?,
                durationSeconds: t['durationSeconds'] as int?,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<DiscogsCollectionPage> collectionFolderReleases({
    required int page,
    int perPage = 100,
  }) async {
    final v = await call(
      'GET',
      '/v1/discogs/collection',
      query: {
        'page': page.toString(),
        'perPage': perPage.clamp(1, 100).toString(),
      },
    );
    final result = _decode(
      () => DiscogsCollectionPage(
        page: v['page'] as int,
        pages: v['pages'] as int,
        totalItems: v['totalItems'] as int,
        items: _rows(v, 'items')
            .map(
              (t) => DiscogsCollectionItem(
                releaseId: t['releaseId'] as int,
                instanceId: t['instanceId'] as int,
                title: t['title'] as String,
                artist: t['artist'] as String,
                year: t['year'] as int?,
                label: t['label'] as String?,
                formats: _strings(t['formats']),
                coverImageUrl: t['coverImageUrl'] as String?,
              ),
            )
            .toList(growable: false),
      ),
    );
    if (result.page != page ||
        result.pages < 0 ||
        result.pages > 1000000 ||
        result.totalItems < 0) {
      throw const DiscogsApiFailure(
        'The server returned invalid collection pagination.',
      );
    }
    return result;
  }

  Future<Uint8List> downloadImage({required String url}) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasFragment ||
        !const {
          'i.discogs.com',
          'img.discogs.com',
          'api-img.discogs.com',
        }.contains(uri.host)) {
      throw const DiscogsApiFailure(
        'Discogs returned an untrusted artwork URL.',
      );
    }
    try {
      // Never attach the installation bearer token to artwork requests.
      return (await transport.send('GET', uri, limit: 20 * 1024 * 1024)).body;
    } on BackendError catch (error) {
      throw backendFailure(error);
    }
  }

  T _decode<T>(T Function() parse) {
    try {
      return parse();
    } on TypeError {
      throw const DiscogsApiFailure('The server returned invalid metadata.');
    } on FormatException {
      throw const DiscogsApiFailure('The server returned invalid metadata.');
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> v, String key) =>
      (v[key] as List<dynamic>).cast<Map<String, dynamic>>();
  List<String> _strings(Object? value) =>
      value == null ? const [] : (value as List<dynamic>).cast<String>();
}

List<String> discogsBarcodeSearchCandidates(String barcode) {
  final normalized = barcode.replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      barcode,
      'barcode',
      'Discogs barcode cannot be empty.',
    );
  }

  final candidates = <String>[normalized];
  if (normalized.length == 13 && normalized.startsWith('0')) {
    candidates.add(normalized.substring(1));
  } else if (normalized.length == 12) {
    candidates.add('0$normalized');
  }

  return List<String>.unmodifiable(candidates.toSet());
}
