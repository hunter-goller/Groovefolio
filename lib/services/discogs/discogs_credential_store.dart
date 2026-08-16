import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

abstract interface class DiscogsCredentialStore {
  Future<DiscogsOAuthCredentials?> readCredentials();
  Future<void> writeCredentials(DiscogsOAuthCredentials credentials);
  Future<void> clearCredentials();
  Future<DiscogsRequestToken?> readPendingRequestToken();
  Future<void> writePendingRequestToken(DiscogsRequestToken token);
  Future<void> clearPendingRequestToken();
}

class SecureDiscogsCredentialStore implements DiscogsCredentialStore {
  SecureDiscogsCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<DiscogsOAuthCredentials?> readCredentials() async {
    final token = await _storage.read(key: 'discogs_access_token');
    final secret = await _storage.read(key: 'discogs_access_token_secret');
    if (token == null || secret == null) return null;
    return DiscogsOAuthCredentials(token: token, tokenSecret: secret);
  }

  @override
  Future<void> writeCredentials(DiscogsOAuthCredentials credentials) async {
    await _storage.write(key: 'discogs_access_token', value: credentials.token);
    await _storage.write(
      key: 'discogs_access_token_secret',
      value: credentials.tokenSecret,
    );
  }

  @override
  Future<void> clearCredentials() async {
    await _storage.delete(key: 'discogs_access_token');
    await _storage.delete(key: 'discogs_access_token_secret');
  }

  @override
  Future<DiscogsRequestToken?> readPendingRequestToken() async {
    final token = await _storage.read(key: 'discogs_request_token');
    final secret = await _storage.read(key: 'discogs_request_token_secret');
    if (token == null || secret == null) return null;
    return DiscogsRequestToken(token: token, tokenSecret: secret);
  }

  @override
  Future<void> writePendingRequestToken(DiscogsRequestToken token) async {
    await _storage.write(key: 'discogs_request_token', value: token.token);
    await _storage.write(
      key: 'discogs_request_token_secret',
      value: token.tokenSecret,
    );
  }

  @override
  Future<void> clearPendingRequestToken() async {
    await _storage.delete(key: 'discogs_request_token');
    await _storage.delete(key: 'discogs_request_token_secret');
  }
}
