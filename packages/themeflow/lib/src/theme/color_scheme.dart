import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../color/oklch.dart';
import '../palette/derive.dart' show retoneAccent;
import '../palette/resolved_palette.dart';

/// The Material 3 [ColorScheme] for [palette].
///
/// Every role is filled in, including the `surfaceContainer` ladder and the
/// `Fixed` roles, so every Material widget's defaults match the palette.
ColorScheme schemeFromPalette(ResolvedPalette palette) {
  final p = palette;
  final dark = p.brightness == Brightness.dark;
  final bg = Oklch.fromColor(p.background);

  Color tone(Color base, double l, double chromaScale, double maxChroma) {
    final o = Oklch.fromColor(base);
    final c = o.c * chromaScale;
    return Oklch(l, c < maxChroma ? c : maxChroma, o.h).toColor();
  }

  Color fixed(Color base) => tone(base, 0.92, 0.4, 0.06);
  Color fixedDim(Color base) => tone(base, 0.84, 0.6, 0.09);
  Color onFixed(Color base) => tone(base, 0.20, 0.7, 0.10);
  Color onFixedVariant(Color base) => tone(base, 0.38, 0.8, 0.12);

  return ColorScheme(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    primaryFixed: fixed(p.primary),
    primaryFixedDim: fixedDim(p.primary),
    onPrimaryFixed: onFixed(p.primary),
    onPrimaryFixedVariant: onFixedVariant(p.primary),
    secondary: p.secondary,
    onSecondary: p.onSecondary,
    secondaryContainer: p.secondaryContainer,
    onSecondaryContainer: p.onSecondaryContainer,
    secondaryFixed: fixed(p.secondary),
    secondaryFixedDim: fixedDim(p.secondary),
    onSecondaryFixed: onFixed(p.secondary),
    onSecondaryFixedVariant: onFixedVariant(p.secondary),
    tertiary: p.tertiary,
    onTertiary: p.onTertiary,
    tertiaryContainer: p.tertiaryContainer,
    onTertiaryContainer: p.onTertiaryContainer,
    tertiaryFixed: fixed(p.tertiary),
    tertiaryFixedDim: fixedDim(p.tertiary),
    onTertiaryFixed: onFixed(p.tertiary),
    onTertiaryFixedVariant: onFixedVariant(p.tertiary),
    error: p.error,
    onError: p.onError,
    errorContainer: p.errorContainer,
    onErrorContainer: p.onErrorContainer,
    surface: p.background,
    onSurface: p.text,
    onSurfaceVariant: p.textSecondary,
    surfaceDim: dark
        ? p.background
        : bg.copyWith(l: (bg.l - 0.06).clamp(0.0, 1.0)).toColor(),
    surfaceBright: dark
        ? bg.copyWith(l: (bg.l + 0.14).clamp(0.0, 1.0)).toColor()
        : p.background,
    surfaceContainerLowest: dark
        ? bg.copyWith(l: (bg.l - 0.04).clamp(0.0, 1.0)).toColor()
        : p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: Color.lerp(p.surface, p.surfaceElevated, 0.5)!,
    surfaceContainerHigh: p.surfaceElevated,
    surfaceContainerHighest: p.fill,
    outline: p.border,
    outlineVariant: p.divider,
    shadow: p.shadow,
    scrim: p.scrim.withValues(alpha: 1),
    inverseSurface: p.inverseSurface,
    onInverseSurface: p.onInverseSurface,
    inversePrimary: retoneAccent(
      p.primary,
      dark ? Brightness.light : Brightness.dark,
      p.style,
    ),
    surfaceTint: p.primary,
  );
}

/// A [CupertinoThemeData] for apps built on `CupertinoApp`, which has no
/// separate dark theme.
CupertinoThemeData cupertinoThemeFromPalette(ResolvedPalette palette) {
  final p = palette;
  return CupertinoThemeData(
    brightness: p.brightness,
    primaryColor: p.primary,
    primaryContrastingColor: p.onPrimary,
    scaffoldBackgroundColor: p.background,
    barBackgroundColor: p.surface.withValues(alpha: 0.94),
    textTheme: CupertinoTextThemeData(
      primaryColor: p.primary,
      textStyle: const CupertinoTextThemeData().textStyle.copyWith(
        color: p.text,
      ),
    ),
  );
}

/// The status and navigation bar style for [palette].
///
/// When [base] is given (your app bar's `systemOverlayStyle`), it's kept and
/// only its gaps are filled in.
SystemUiOverlayStyle systemBarsStyle(
  ResolvedPalette palette, {
  SystemUiOverlayStyle? base,
}) {
  final dark = palette.brightness == Brightness.dark;
  final b =
      base ?? (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: base?.statusBarColor ?? const Color(0x00000000),
    statusBarIconBrightness: base?.statusBarIconBrightness ?? icons,
    statusBarBrightness:
        base?.statusBarBrightness ??
        (dark ? Brightness.dark : Brightness.light),
    systemNavigationBarColor:
        base?.systemNavigationBarColor ?? palette.background,
    systemNavigationBarIconBrightness:
        base?.systemNavigationBarIconBrightness ?? icons,
    systemNavigationBarDividerColor:
        base?.systemNavigationBarDividerColor ?? const Color(0x00000000),
    systemStatusBarContrastEnforced: b.systemStatusBarContrastEnforced,
    systemNavigationBarContrastEnforced: b.systemNavigationBarContrastEnforced,
  );
}
