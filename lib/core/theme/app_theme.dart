// Builds Material ThemeData for light and dark modes from AppColors and fonts.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/theme/app_motion.dart';

/// Central theme: Outfit (mixed-case Latin) with Tajawal fallback for Arabic.
class AppTheme {
  AppTheme._();

  /// Arabic face, used as the fallback for every style.
  static const String arabic = 'Tajawal';

  /// Latin face (mixed case) and the primary family.
  static const String english = 'Outfit';

  /// Font fallback list for text styles.
  static const List<String> fallback = [arabic];

  /// The light [ThemeData].
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.lightAccent,
      cardColor: AppColors.lightSurface,
      fontFamily: english,
      fontFamilyFallback: fallback,
      colorScheme: _colorScheme(Brightness.light),
      switchTheme: _switchTheme(
        accent: AppColors.lightAccent,
        onAccent: AppColors.lightOnAccent,
        secondary: AppColors.lightTextSecondary,
      ),
      textTheme: _textTheme(
        primary: AppColors.lightTextPrimary,
        secondary: AppColors.lightTextSecondary,
        accent: AppColors.lightAccent,
      ),
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: _appBarTheme(
        background: AppColors.lightSurface,
        foreground: AppColors.lightTextPrimary,
      ),
    );
  }

  /// The dark [ThemeData].
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.darkAccent,
      cardColor: AppColors.darkSurface,
      fontFamily: english,
      fontFamilyFallback: fallback,
      colorScheme: _colorScheme(Brightness.dark),
      switchTheme: _switchTheme(
        accent: AppColors.darkAccent,
        onAccent: AppColors.darkOnAccent,
        secondary: AppColors.darkTextSecondary,
      ),
      textTheme: _textTheme(
        primary: AppColors.darkTextPrimary,
        secondary: AppColors.darkTextSecondary,
        accent: AppColors.darkAccent,
      ),
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: _appBarTheme(
        background: AppColors.darkSurface,
        foreground: AppColors.darkTextPrimary,
      ),
    );
  }

  // Every Material color role maps to an app token, so no widget falls back
  // to Material's default purple or teal.
  static ColorScheme _colorScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final accent = dark ? AppColors.darkAccent : AppColors.lightAccent;
    final onAccent = dark ? AppColors.darkOnAccent : AppColors.lightOnAccent;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final destructive = dark
        ? AppColors.darkDestructive
        : AppColors.lightDestructive;
    final container = accent.withValues(alpha: 0.18);

    return ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: container,
      onPrimaryContainer: textPrimary,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: container,
      onSecondaryContainer: textPrimary,
      tertiary: accent,
      onTertiary: onAccent,
      error: destructive,
      onError: onAccent,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: textSecondary,
      outlineVariant: textSecondary.withValues(alpha: 0.3),
      surfaceTint: Colors.transparent,
    );
  }

  // One switch look: an on-accent thumb on the accent track when on, a quiet
  // outlined track when off.
  static SwitchThemeData _switchTheme({
    required Color accent,
    required Color onAccent,
    required Color secondary,
  }) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return onAccent;
        return secondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return states.contains(WidgetState.disabled)
              ? accent.withValues(alpha: 0.4)
              : accent;
        }
        return secondary.withValues(alpha: 0.12);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return secondary.withValues(alpha: 0.4);
      }),
    );
  }

  // iOS and macOS slide with the edge swipe-back gesture; Android follows
  // the predictive back gesture and zooms for button and code navigation.
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ReducedMotionPageTransitionsBuilder(
        PredictiveBackFullscreenPageTransitionsBuilder(),
      ),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ReducedMotionPageTransitionsBuilder(
        ZoomPageTransitionsBuilder(),
      ),
      TargetPlatform.linux: ReducedMotionPageTransitionsBuilder(
        ZoomPageTransitionsBuilder(),
      ),
    },
  );

  static AppBarTheme _appBarTheme({
    required Color background,
    required Color foreground,
  }) {
    return AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      foregroundColor: foreground,
      titleTextStyle: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: foreground,
      ),
      iconTheme: IconThemeData(color: foreground),
    );
  }

  static TextTheme _textTheme({
    required Color primary,
    required Color secondary,
    required Color accent,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        fontSize: 40,
        fontWeight: FontWeight.bold,

        color: accent,
      ),
      displayMedium: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1,
        color: accent,
      ),
      headlineSmall: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        color: primary,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontFamily: english,
        fontFamilyFallback: fallback,
        color: secondary,
      ),
    );
  }
}
