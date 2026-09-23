import 'package:url_launcher/url_launcher.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_credential_store.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

/// Coordinates the app's current, direct Discogs OAuth 1.0a flow.
///
/// The pending request token and connected access token are stored through
/// [DiscogsCredentialStore], never in the collection database.
class DiscogsAuthService {
  const DiscogsAuthService({
    required DiscogsApiClient apiClient,
    required DiscogsCredentialStore credentialStore,
  }) : this._(apiClient, credentialStore);

  const DiscogsAuthService._(this._apiClient, this._credentialStore);

  final DiscogsApiClient _apiClient;
  final DiscogsCredentialStore _credentialStore;

  /// Returns null when disconnected; otherwise verifies identity over HTTP.
  /// An offline/provider failure throws and does not by itself erase the saved
  /// credentials. A failed account lookup is not proof of a disconnected user.
  Future<DiscogsAccount?> currentAccount() async {
    final credentials = await _credentialStore.readCredentials();
    return credentials == null ? null : _apiClient.identity(credentials);
  }

  /// Persists the temporary request token before returning the browser URL
  /// so a cold-start callback can still complete the same authorization.
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

  /// Exchanges only a callback matching the saved request token.
  /// Clears newly stored access credentials if identity verification fails.
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

  Future<void> cancelAuthorization() async {
    await _credentialStore.clearPendingRequestToken();
  }

  /// Removes local access credentials and any unfinished request token.
  /// This does not revoke the grant at Discogs itself.
  Future<void> disconnect() async {
    await _credentialStore.clearCredentials();
    await _credentialStore.clearPendingRequestToken();
  }
}
