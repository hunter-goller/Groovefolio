import 'package:url_launcher/url_launcher.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_credential_store.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

class DiscogsAuthService {
  const DiscogsAuthService({
    required DiscogsApiClient apiClient,
    required DiscogsCredentialStore credentialStore,
  }) : this._(apiClient, credentialStore);

  const DiscogsAuthService._(this._apiClient, this._credentialStore);

  final DiscogsApiClient _apiClient;
  final DiscogsCredentialStore _credentialStore;

  Future<DiscogsAccount?> currentAccount() async {
    final credentials = await _credentialStore.readCredentials();
    return credentials == null ? null : _apiClient.identity(credentials);
  }

  Future<Uri> beginAuthorization() async {
    final requestToken = await _apiClient.requestToken();
    await _credentialStore.writePendingRequestToken(requestToken);
    return _apiClient.authorizationUri(requestToken.token);
  }

  Future<void> launchAuthorization() async {
    final uri = await beginAuthorization();
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const DiscogsNetworkFailure(
        'Could not open Discogs authorization.',
      );
    }
  }

  Future<DiscogsAccount> completeAuthorization({
    required String oauthToken,
    required String verifier,
  }) async {
    final pending = await _credentialStore.readPendingRequestToken();
    if (pending == null || pending.token != oauthToken) {
      throw const DiscogsAuthenticationFailure(
        'Discogs authorization session is missing or expired.',
      );
    }

    final credentials = await _apiClient.exchangeVerifier(
      requestToken: pending,
      verifier: verifier,
    );
    await _credentialStore.writeCredentials(credentials);
    await _credentialStore.clearPendingRequestToken();

    try {
      return await _apiClient.identity(credentials);
    } catch (_) {
      await _credentialStore.clearCredentials();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _credentialStore.clearCredentials();
    await _credentialStore.clearPendingRequestToken();
  }
}
