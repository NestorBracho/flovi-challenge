import 'package:flutter/material.dart';

import 'flovi_tokens.dart';

/// Builds the app's single (light-only, see Task 3 in main.dart) [ThemeData],
/// carrying [FloviTokens] as a registered [ThemeExtension] so every
/// screen/widget can retrieve it via `Theme.of(context).extension<FloviTokens>()`.
ThemeData buildFloviTheme() {
  const tokens = FloviTokens.light;

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: tokens.surfaceCanvas,
    fontFamily:
        '-apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif',
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: Brightness.light,
      surface: tokens.surfaceCard,
      primary: tokens.accent,
    ),
    textTheme: TextTheme(
      headlineMedium: tokens.display,
      titleLarge: tokens.heading,
      bodyMedium: tokens.body,
      bodyLarge: tokens.bodyStrong,
      labelSmall: tokens.meta,
      labelLarge: tokens.label,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.surfaceCard,
      indicatorColor: tokens.accentTint,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return tokens.label.copyWith(
          color: selected ? tokens.accent : tokens.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? tokens.accent : tokens.textSecondary,
        );
      }),
    ),
    extensions: const [tokens],
  );
}
