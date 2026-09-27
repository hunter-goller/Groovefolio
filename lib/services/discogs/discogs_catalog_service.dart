import 'dart:typed_data';

import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

/// Discogs catalog operations used by Add Record and collection import.
/// Calls use the current installation token; Discogs credentials stay on the server.
abstract interface class DiscogsCatalogService {
  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required String artist,
    required String title,
  });

  Future<List<DiscogsReleaseSearchResult>> searchReleasesByBarcode(
    String barcode,
  );

  Future<DiscogsReleaseDetails> release(int releaseId);

  /// Reads one page of folder zero; the importer owns pagination and local
  /// duplicate review. This interface does not write to the collection.
  Future<DiscogsCollectionPage> collectionPage({
    required String username,
    required int page,
    int perPage = 100,
  });

  Future<Uint8List> downloadArtwork(String url);
}

class DefaultDiscogsCatalogService implements DiscogsCatalogService {
  const DefaultDiscogsCatalogService(this._apiClient);

  final DiscogsApiClient _apiClient;

  @override
  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required String artist,
    required String title,
  }) async {
    return _apiClient.searchReleases(artist: artist, title: title, limit: 5);
  }

  @override
  Future<List<DiscogsReleaseSearchResult>> searchReleasesByBarcode(
    String barcode,
  ) async {
    return _apiClient.searchReleasesByBarcode(barcode: barcode, limit: 10);
  }

  @override
  Future<DiscogsCollectionPage> collectionPage({
    required String username,
    required int page,
    int perPage = 100,
  }) async {
    return _apiClient.collectionFolderReleases(page: page, perPage: perPage);
  }

  @override
  Future<DiscogsReleaseDetails> release(int releaseId) async {
    return _apiClient.release(releaseId: releaseId);
  }

  @override
  Future<Uint8List> downloadArtwork(String url) async {
    return _apiClient.downloadImage(url: url);
  }
}
