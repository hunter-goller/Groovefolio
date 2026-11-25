import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/tokens.dart';

extension AppThemeDataX on ThemeData {
  AppThemeTokens get appTokens {
    final tokens = extension<AppThemeTokens>();
    assert(tokens != null, 'AppThemeTokens must be registered on ThemeData.');
    return tokens!;
  }
}

extension AppThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  AppThemeTokens get tokens => theme.appTokens;
}
