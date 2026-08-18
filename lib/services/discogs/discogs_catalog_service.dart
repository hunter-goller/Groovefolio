import 'dart:typed_data';

import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_credential_store.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

abstract interface class DiscogsCatalogService {
  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required String artist,
    required String title,
  });

  Future<DiscogsReleaseDetails> release(int releaseId);

  Future<Uint8List> downloadArtwork(String url);
}

class DefaultDiscogsCatalogService implements DiscogsCatalogService {
  const DefaultDiscogsCatalogService(this._apiClient, this._credentialStore);

  final DiscogsApiClient _apiClient;
  final DiscogsCredentialStore _credentialStore;

  @override
  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required String artist,
    required String title,
  }) async {
    final credentials = await _requireCredentials();
    return _apiClient.searchReleases(
      credentials: credentials,
      artist: artist,
      title: title,
      limit: 5,
    );
  }

  @override
  Future<DiscogsReleaseDetails> release(int releaseId) async {
    final credentials = await _requireCredentials();
    return _apiClient.release(credentials: credentials, releaseId: releaseId);
  }

  @override
  Future<Uint8List> downloadArtwork(String url) async {
    final credentials = await _requireCredentials();
    return _apiClient.downloadImage(credentials: credentials, url: url);
  }

  Future<DiscogsOAuthCredentials> _requireCredentials() async {
    final credentials = await _credentialStore.readCredentials();
    if (credentials == null) {
      throw const DiscogsAuthenticationFailure(
        'Connect a Discogs account in Settings before searching Discogs.',
      );
    }
    return credentials;
  }
}
