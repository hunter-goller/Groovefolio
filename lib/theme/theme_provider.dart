import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

/// Controls whether Vinyl App follows the system theme or forces light/dark.
///
/// Persistence of a manual choice is intentionally out of scope for
/// VinylApp-008. The provider owns the in-memory override for the app session.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;

  void setMode(ThemeMode mode) {
    if (state == mode) return;
    state = mode;
  }

  void useSystem() => setMode(ThemeMode.system);

  void useLight() => setMode(ThemeMode.light);

  void useDark() => setMode(ThemeMode.dark);
}
