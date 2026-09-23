import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ThemePreferenceStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureThemePreferenceStore implements ThemePreferenceStore {
  const SecureThemePreferenceStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'groovefolio.appearance.theme';

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

final themePreferenceStoreProvider = Provider<ThemePreferenceStore>(
  (ref) => const SecureThemePreferenceStore(),
);
