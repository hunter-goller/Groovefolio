import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/tokens.dart';

/// Application-wide Material themes for Groovefolio.
abstract final class AppTheme {
  static ThemeData get light =>
      _build(brightness: Brightness.light, tokens: AppThemeTokens.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, tokens: AppThemeTokens.dark);

  static ThemeData _build({
    required Brightness brightness,
    required AppThemeTokens tokens,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppThemeTokens.accent,
      brightness: brightness,
      primary: AppThemeTokens.accent,
      onPrimary: Colors.black,
      surface: tokens.surface,
      onSurface: tokens.text,
    );

    final base = ThemeData.from(colorScheme: colorScheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.background,
      cardColor: tokens.surface,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.textMuted.withValues(alpha: 0.24),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide(
            color: tokens.textMuted.withValues(alpha: 0.28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: const BorderSide(
            color: AppThemeTokens.accent,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppThemeTokens.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space24,
            vertical: tokens.space12,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
      ),
    );
  }
}
