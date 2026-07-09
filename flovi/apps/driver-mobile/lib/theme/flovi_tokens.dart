import 'package:flutter/material.dart';

/// DESIGN.md's token set, expressed as a Flutter [ThemeExtension] rather than
/// forced into Material's fixed ColorScheme/TextTheme slots — DESIGN.md's
/// names (surface-tint, status-booked-text, ...) don't correspond to any
/// Material ColorScheme field, and ThemeExtension is Flutter's own mechanism
/// for exactly this situation.
@immutable
class FloviTokens extends ThemeExtension<FloviTokens> {
  const FloviTokens({
    required this.surfaceCanvas,
    required this.surfaceCard,
    required this.surfaceTint,
    required this.borderSubtle,
    required this.borderHairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentTint,
    required this.focusRing,
    required this.statusUnbooked,
    required this.statusUnbookedText,
    required this.statusUnbookedTint,
    required this.statusBooked,
    required this.statusBookedText,
    required this.statusBookedTint,
    required this.statusCompleted,
    required this.statusCompletedText,
    required this.statusCompletedTint,
    required this.statusCancelled,
    required this.statusCancelledText,
    required this.statusCancelledTint,
    required this.display,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.meta,
    required this.label,
    required this.roundedXs,
    required this.roundedSm,
    required this.roundedMd,
    required this.roundedLg,
    required this.roundedFull,
    required this.spacing1,
    required this.spacing2,
    required this.spacing3,
    required this.spacing4,
    required this.spacing5,
    required this.spacing6,
    required this.spacing7,
    required this.spacing8,
    required this.raisedShadow,
  });

  // Colors
  final Color surfaceCanvas;
  final Color surfaceCard;
  final Color surfaceTint;
  final Color borderSubtle;
  final Color borderHairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentTint;
  final Color focusRing;
  final Color statusUnbooked;
  final Color statusUnbookedText;
  final Color statusUnbookedTint;
  final Color statusBooked;
  final Color statusBookedText;
  final Color statusBookedTint;
  final Color statusCompleted;
  final Color statusCompletedText;
  final Color statusCompletedTint;
  final Color statusCancelled;
  final Color statusCancelledText;
  final Color statusCancelledTint;

  // Typography
  final TextStyle display;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle meta;
  final TextStyle label;

  // Rounded scale
  final double roundedXs;
  final double roundedSm;
  final double roundedMd;
  final double roundedLg;
  final double roundedFull;

  // Spacing scale (DESIGN.md steps 1-8)
  final double spacing1;
  final double spacing2;
  final double spacing3;
  final double spacing4;
  final double spacing5;
  final double spacing6;
  final double spacing7;
  final double spacing8;

  // Elevation — "raised" surfaces use this soft, warm-toned shadow instead of
  // Material's own default (neutral gray/black) Card/Material elevation shadow.
  // "flat" surfaces (canvas, tab bar) simply omit this — no separate token needed.
  final List<BoxShadow> raisedShadow;

  static const FloviTokens light = FloviTokens(
    surfaceCanvas: Color(0xFFFAF6F0),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFFF5EEE3),
    borderSubtle: Color(0xFFEAE0D0),
    borderHairline: Color(0xFFF0E9DC),
    textPrimary: Color(0xFF3D3630),
    textSecondary: Color(0xFF786F65),
    textTertiary: Color(0xFFB0A697),
    accent: Color(0xFFBF582A),
    accentTint: Color(0xFFF4E1D2),
    focusRing: Color(0xFFBF582A),
    statusUnbooked: Color(0xFFD99A2B),
    statusUnbookedText: Color(0xFF8A5A0A),
    statusUnbookedTint: Color(0xFFFBEDD1),
    statusBooked: Color(0xFF3E7C8C),
    statusBookedText: Color(0xFF2A5C68),
    statusBookedTint: Color(0xFFDEEBEE),
    statusCompleted: Color(0xFF5B8C6E),
    statusCompletedText: Color(0xFF3E6B51),
    statusCompletedTint: Color(0xFFE2EEE6),
    statusCancelled: Color(0xFFB8503D),
    statusCancelledText: Color(0xFF8F3D2E),
    statusCancelledTint: Color(0xFFF6E1DB),
    display: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.24, // -0.01em at 24px
      color: Color(0xFF3D3630),
    ),
    heading: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Color(0xFF3D3630),
    ),
    body: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF3D3630),
    ),
    bodyStrong: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Color(0xFF3D3630),
    ),
    meta: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: Color(0xFF786F65),
    ),
    label: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.345, // 0.03em at 11.5px
      color: Color(0xFF3D3630),
    ),
    roundedXs: 10,
    roundedSm: 12,
    roundedMd: 16,
    roundedLg: 22,
    roundedFull: 9999,
    spacing1: 4,
    spacing2: 8,
    spacing3: 12,
    spacing4: 16,
    spacing5: 20,
    spacing6: 24,
    spacing7: 32,
    spacing8: 40,
    raisedShadow: [
      BoxShadow(
        color: Color(
          0x293D3630,
        ), // text-primary at ~16% opacity — warm, never a hard black shadow
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  );

  @override
  FloviTokens copyWith({
    Color? surfaceCanvas,
    Color? surfaceCard,
    Color? surfaceTint,
    Color? borderSubtle,
    Color? borderHairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentTint,
    Color? focusRing,
    Color? statusUnbooked,
    Color? statusUnbookedText,
    Color? statusUnbookedTint,
    Color? statusBooked,
    Color? statusBookedText,
    Color? statusBookedTint,
    Color? statusCompleted,
    Color? statusCompletedText,
    Color? statusCompletedTint,
    Color? statusCancelled,
    Color? statusCancelledText,
    Color? statusCancelledTint,
    TextStyle? display,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? meta,
    TextStyle? label,
    double? roundedXs,
    double? roundedSm,
    double? roundedMd,
    double? roundedLg,
    double? roundedFull,
    double? spacing1,
    double? spacing2,
    double? spacing3,
    double? spacing4,
    double? spacing5,
    double? spacing6,
    double? spacing7,
    double? spacing8,
    List<BoxShadow>? raisedShadow,
  }) {
    return FloviTokens(
      surfaceCanvas: surfaceCanvas ?? this.surfaceCanvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderHairline: borderHairline ?? this.borderHairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      focusRing: focusRing ?? this.focusRing,
      statusUnbooked: statusUnbooked ?? this.statusUnbooked,
      statusUnbookedText: statusUnbookedText ?? this.statusUnbookedText,
      statusUnbookedTint: statusUnbookedTint ?? this.statusUnbookedTint,
      statusBooked: statusBooked ?? this.statusBooked,
      statusBookedText: statusBookedText ?? this.statusBookedText,
      statusBookedTint: statusBookedTint ?? this.statusBookedTint,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      statusCompletedText: statusCompletedText ?? this.statusCompletedText,
      statusCompletedTint: statusCompletedTint ?? this.statusCompletedTint,
      statusCancelled: statusCancelled ?? this.statusCancelled,
      statusCancelledText: statusCancelledText ?? this.statusCancelledText,
      statusCancelledTint: statusCancelledTint ?? this.statusCancelledTint,
      display: display ?? this.display,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      meta: meta ?? this.meta,
      label: label ?? this.label,
      roundedXs: roundedXs ?? this.roundedXs,
      roundedSm: roundedSm ?? this.roundedSm,
      roundedMd: roundedMd ?? this.roundedMd,
      roundedLg: roundedLg ?? this.roundedLg,
      roundedFull: roundedFull ?? this.roundedFull,
      spacing1: spacing1 ?? this.spacing1,
      spacing2: spacing2 ?? this.spacing2,
      spacing3: spacing3 ?? this.spacing3,
      spacing4: spacing4 ?? this.spacing4,
      spacing5: spacing5 ?? this.spacing5,
      spacing6: spacing6 ?? this.spacing6,
      spacing7: spacing7 ?? this.spacing7,
      spacing8: spacing8 ?? this.spacing8,
      raisedShadow: raisedShadow ?? this.raisedShadow,
    );
  }

  @override
  FloviTokens lerp(ThemeExtension<FloviTokens>? other, double t) {
    // Light mode only (AC #1, Task 3) — no second palette to interpolate
    // toward, so this is intentionally a no-op rather than a real lerp.
    if (other is! FloviTokens) return this;
    return t < 0.5 ? this : other;
  }
}
