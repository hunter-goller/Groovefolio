import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Each value is one secure-storage write, so rotation never splits token pairs.
abstract interface class BackendStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clearLegacyDiscogs();
}

class SecureBackendStore implements BackendStore {
  SecureBackendStore(String origin, {FlutterSecureStorage? storage})
    : _prefix = 'groovefolio_backend_${Uri.encodeComponent(origin)}_',
      _storage = storage ?? const FlutterSecureStorage();
  final String _prefix;
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');
  @override
  Future<void> clearLegacyDiscogs() async {
    for (final key in [
      'discogs_access_token',
      'discogs_access_token_secret',
      'discogs_request_token',
      'discogs_request_token_secret',
    ]) {
      await _storage.delete(key: key);
    }
  }
}
