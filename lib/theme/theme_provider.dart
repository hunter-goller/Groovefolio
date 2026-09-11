import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/theme/theme_preference_store.dart';

part 'theme_provider.g.dart';

/// Controls whether Groovefolio follows the system theme or forces light/dark.
///
/// Restores the saved choice without overwriting a newer user selection.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  int _revision = 0;
  Future<void> _writes = Future<void>.value();

  @override
  ThemeMode build() {
    final store = ref.read(themePreferenceStoreProvider);
    final revision = _revision;
    store
        .read()
        .then((value) {
          if (!ref.mounted || revision != _revision) {
            return;
          }
          state = switch (value) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
        })
        .catchError((Object _) {});
    return ThemeMode.system;
  }

  Future<bool> setMode(ThemeMode mode) async {
    _revision++;
    state = mode;
    final store = ref.read(themePreferenceStoreProvider);
    final write = _writes.then((_) => store.write(mode.name));
    _writes = write.catchError((Object _) {});
    try {
      await write;
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> useSystem() => setMode(ThemeMode.system);

  Future<bool> useLight() => setMode(ThemeMode.light);

  Future<bool> useDark() => setMode(ThemeMode.dark);
}
