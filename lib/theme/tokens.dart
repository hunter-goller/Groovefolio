import 'package:flutter/material.dart';

/// Vinyl App design tokens that are not represented directly by [ColorScheme]
/// or [TextTheme].
///
/// Attach these to [ThemeData.extensions] so widgets can read spacing, radii,
/// and app-specific semantic colors from the active theme.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.text,
    required this.textMuted,
    this.space4 = 4,
    this.space8 = 8,
    this.space12 = 12,
    this.space16 = 16,
    this.space24 = 24,
    this.space32 = 32,
    this.radiusSmall = 8,
    this.radiusMedium = 12,
    this.radiusLarge = 16,
    this.radiusXLarge = 24,
  });

  static const Color accent = Color(0xFFD4622A);

  static const AppThemeTokens light = AppThemeTokens(
    background: Color(0xFFF7F4F0),
    surface: Color(0xFFFFFCF9),
    surfaceElevated: Color(0xFFF0EAE4),
    text: Color(0xFF211F1D),
    textMuted: Color(0xFF6F6861),
  );

  static const AppThemeTokens dark = AppThemeTokens(
    background: Color(0xFF12100F),
    surface: Color(0xFF1B1816),
    surfaceElevated: Color(0xFF26211E),
    text: Color(0xFFF5F1ED),
    textMuted: Color(0xFFB8AEA5),
  );

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color text;
  final Color textMuted;

  final double space4;
  final double space8;
  final double space12;
  final double space16;
  final double space24;
  final double space32;

  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusXLarge;

  @override
  AppThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? text,
    Color? textMuted,
    double? space4,
    double? space8,
    double? space12,
    double? space16,
    double? space24,
    double? space32,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? radiusXLarge,
  }) {
    return AppThemeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      space4: space4 ?? this.space4,
      space8: space8 ?? this.space8,
      space12: space12 ?? this.space12,
      space16: space16 ?? this.space16,
      space24: space24 ?? this.space24,
      space32: space32 ?? this.space32,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusXLarge: radiusXLarge ?? this.radiusXLarge,
    );
  }

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) {
      return this;
    }

    double lerpDouble(double a, double b) => a + (b - a) * t;

    return AppThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      space4: lerpDouble(space4, other.space4),
      space8: lerpDouble(space8, other.space8),
      space12: lerpDouble(space12, other.space12),
      space16: lerpDouble(space16, other.space16),
      space24: lerpDouble(space24, other.space24),
      space32: lerpDouble(space32, other.space32),
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall),
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium),
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge),
      radiusXLarge: lerpDouble(radiusXLarge, other.radiusXLarge),
    );
  }
}
