import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../color/contrast.dart';
import '../color/oklch.dart';
import 'color_token.dart';
import 'contrast_report.dart';
import 'dark_style.dart';
import 'palette_token.dart';
import 'resolved_palette.dart';
import 'theme_palette.dart';

/// The light and dark palettes resolved from your input.
@immutable
class ResolvedPalettes {
  /// Creates a pair of palettes.
  const ResolvedPalettes({required this.light, required this.dark});

  /// The light palette.
  final ResolvedPalette light;

  /// The dark palette.
  final ResolvedPalette dark;

  /// The palette for [brightness].
  ResolvedPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  bool operator ==(Object other) =>
      other is ResolvedPalettes && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

/// Resolves every token, in both brightnesses.
///
/// [light] and [dark] work the same way. A color you set wins. A color you
/// didn't set is derived from the other palette, or failing that, from the
/// defaults. Derived colors then get a contrast pass: each one is moved in
/// lightness, by the smallest amount, until it meets its minimum in
/// [contrastRules]. Colors you set are never changed.
///
/// ```dart
/// final palettes = resolvePalettes(light: const ThemePalette(primary: brand));
/// palettes.dark.surface; // derived
/// ```
ResolvedPalettes resolvePalettes({
  ThemePalette? light,
  ThemePalette? dark,
  DarkStyle style = const DarkStyle(),
}) {
  if (light == null && dark == null) {
    throw ArgumentError('resolvePalettes needs a light or a dark palette.');
  }
  final seedSource = light?.seed != null
      ? light
      : (dark?.seed != null ? dark : null);
  final lightGiven = _given(light, seedSource, Brightness.light);
  final darkGiven = _given(dark, seedSource, Brightness.dark);
  final neutral = light?.neutral ?? dark?.neutral;
  return ResolvedPalettes(
    light: _resolve(Brightness.light, lightGiven, darkGiven, neutral, style),
    dark: _resolve(Brightness.dark, darkGiven, lightGiven, neutral, style),
  );
}

/// Derives the dark value of a custom [token] for [palette].
Color deriveCustomToken(ColorToken token, ResolvedPalette palette) =>
    retoneUnknown(
      token.light,
      token.role,
      to: palette.brightness,
      style: palette.style,
      toBackground: palette.background,
    );

/// Carries [color] into the [to] brightness according to its [role].
///
/// This is for colors that match no token, such as custom tokens or colors
/// inside a theme being recolored. The background lightness of both sides
/// keeps elevation order intact: a card lighter than its background stays
/// lighter than the new background. Content and accents are then checked
/// against [toBackground] unless [enforceContrast] is false.
Color retoneUnknown(
  Color color,
  TokenRole role, {
  required Brightness to,
  required DarkStyle style,
  required Color toBackground,
  Color? fromBackground,
  bool enforceContrast = true,
}) {
  if (role == TokenRole.fixed || color.a == 0) return color;
  final src = Oklch.fromColor(color);
  final dark = to == Brightness.dark;
  final toBgL = Oklch.fromColor(toBackground).l;
  final fromBgL = fromBackground != null
      ? Oklch.fromColor(fromBackground).l
      : (dark ? 0.98 : 0.18);
  double l;
  var c = src.c;
  switch (role) {
    case TokenRole.surface:
      if (dark) {
        l = src.l >= 0.5
            ? math.min(toBgL + 0.6 * (src.l - fromBgL).abs(), 0.40)
            : src.l.clamp(0.12, 0.40);
        c = style.surfaces == DarkSurfaces.tinted ? math.min(src.c, 0.025) : 0;
      } else {
        l = src.l <= 0.5
            ? (toBgL + 0.6 * (src.l - fromBgL)).clamp(0.85, 1.0)
            : src.l.clamp(0.85, 1.0);
        c = math.min(src.c, 0.03);
      }
    case TokenRole.container:
      l = dark
          ? (1.26 - src.l).clamp(0.22, 0.45)
          : (1.26 - src.l).clamp(0.80, 0.97);
      c = dark ? math.min(src.c * 0.7, 0.09) : math.min(src.c, 0.05);
    case TokenRole.content:
    case TokenRole.onColor:
      if (dark) {
        l = src.l <= 0.6 ? 0.93 - 0.6 * (src.l - 0.2) : math.max(src.l, 0.69);
      } else {
        l = src.l >= 0.69 ? 0.2 + (0.93 - src.l) / 0.6 : math.min(src.l, 0.6);
      }
      l = l.clamp(0.02, 0.99);
      c = src.c * 0.85;
    case TokenRole.outline:
      l = dark
          ? (0.55 - 0.862 * (src.l - 0.62)).clamp(0.20, 0.75)
          : (0.62 + (0.55 - src.l) / 0.862).clamp(0.25, 0.95);
      c = math.min(src.c, 0.04);
    case TokenRole.accent:
      l = dark
          ? math.max(src.l, style.accentLightness / 100)
          : math.min(src.l, 0.52);
      c = dark ? src.c * 0.85 : src.c;
    case TokenRole.fixed:
      return color;
  }
  final result = Oklch(l, c, src.h, src.alpha).toColor();
  if (!enforceContrast) return result;
  return switch (role) {
    TokenRole.content ||
    TokenRole.onColor => ensureContrast(result, toBackground, 4.5),
    TokenRole.accent => ensureContrast(result, toBackground, 3),
    _ => result,
  };
}

/// Re-tones a brand or status color for [to].
///
/// In dark mode it's raised to [DarkStyle.accentLightness] and calmed a
/// little; in light mode it's brought down to a lightness that reads on
/// white.
Color retoneAccent(Color color, Brightness to, DarkStyle style) {
  final src = Oklch.fromColor(color);
  return to == Brightness.dark
      ? Oklch(
          math.max(src.l, style.accentLightness / 100),
          src.c * 0.85,
          src.h,
          src.alpha,
        ).toColor()
      : Oklch(math.min(src.l, 0.52), src.c, src.h, src.alpha).toColor();
}

final int _n = PaletteToken.values.length;

List<Color?> _given(
  ThemePalette? own,
  ThemePalette? seedSource,
  Brightness brightness,
) {
  final values = List<Color?>.filled(_n, null);
  final seeded = own?.seed != null ? own : seedSource;
  if (seeded != null) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seeded.seed!,
      brightness: brightness,
      dynamicSchemeVariant: seeded.seedVariant,
    );
    final fromScheme = ThemePalette.fromColorScheme(scheme).values;
    for (var i = 0; i < _n; i++) {
      values[i] = fromScheme[i];
    }
  }
  if (own != null) {
    final explicit = own.values;
    for (var i = 0; i < _n; i++) {
      final color = explicit[i];
      if (color != null) values[i] = color;
    }
  }
  return values;
}

// Starting lightness (OKLCH L) for the neutral tokens. DESIGN.md §6.
const Map<PaletteToken, double> _lightL = {
  PaletteToken.background: 0.98,
  PaletteToken.surface: 1.0,
  PaletteToken.surfaceElevated: 1.0,
  PaletteToken.fill: 0.95,
  PaletteToken.inverseSurface: 0.25,
  PaletteToken.text: 0.20,
  PaletteToken.textSecondary: 0.45,
  PaletteToken.textTertiary: 0.55,
  PaletteToken.border: 0.62,
  PaletteToken.divider: 0.91,
  PaletteToken.skeleton: 0.93,
  PaletteToken.skeletonHighlight: 0.97,
};

const Map<PaletteToken, double> _darkL = {
  PaletteToken.background: 0.18,
  PaletteToken.surface: 0.22,
  PaletteToken.surfaceElevated: 0.26,
  PaletteToken.fill: 0.28,
  PaletteToken.inverseSurface: 0.90,
  PaletteToken.text: 0.93,
  PaletteToken.textSecondary: 0.78,
  PaletteToken.textTertiary: 0.66,
  PaletteToken.border: 0.55,
  PaletteToken.divider: 0.30,
  PaletteToken.skeleton: 0.26,
  PaletteToken.skeletonHighlight: 0.31,
};

const Map<PaletteToken, double> _blackL = {
  PaletteToken.background: 0.0,
  PaletteToken.surface: 0.18,
  PaletteToken.surfaceElevated: 0.22,
  PaletteToken.fill: 0.25,
  PaletteToken.inverseSurface: 0.90,
  PaletteToken.text: 0.93,
  PaletteToken.textSecondary: 0.78,
  PaletteToken.textTertiary: 0.66,
  PaletteToken.border: 0.55,
  PaletteToken.divider: 0.28,
  PaletteToken.skeleton: 0.22,
  PaletteToken.skeletonHighlight: 0.27,
};

const _surfaceTokens = {
  PaletteToken.background,
  PaletteToken.surface,
  PaletteToken.surfaceElevated,
  PaletteToken.fill,
  PaletteToken.inverseSurface,
  PaletteToken.skeleton,
  PaletteToken.skeletonHighlight,
};

// Light defaults for the status colors. Each reads at 4.5:1 or more on white.
const Map<PaletteToken, Color> _statusLight = {
  PaletteToken.error: Color(0xFFB3261E),
  PaletteToken.success: Color(0xFF2E7D32),
  PaletteToken.warning: Color(0xFFB45309),
  PaletteToken.info: Color(0xFF0B57D0),
};

const _containers = [
  (PaletteToken.primary, PaletteToken.primaryContainer),
  (PaletteToken.secondary, PaletteToken.secondaryContainer),
  (PaletteToken.tertiary, PaletteToken.tertiaryContainer),
  (PaletteToken.error, PaletteToken.errorContainer),
  (PaletteToken.success, PaletteToken.successContainer),
  (PaletteToken.warning, PaletteToken.warningContainer),
  (PaletteToken.info, PaletteToken.infoContainer),
];

const _onColors = [
  (PaletteToken.primary, PaletteToken.onPrimary),
  (PaletteToken.secondary, PaletteToken.onSecondary),
  (PaletteToken.tertiary, PaletteToken.onTertiary),
  (PaletteToken.error, PaletteToken.onError),
  (PaletteToken.success, PaletteToken.onSuccess),
  (PaletteToken.warning, PaletteToken.onWarning),
  (PaletteToken.info, PaletteToken.onInfo),
  (PaletteToken.inverseSurface, PaletteToken.onInverseSurface),
];

const _onContainers = [
  (PaletteToken.primaryContainer, PaletteToken.onPrimaryContainer),
  (PaletteToken.secondaryContainer, PaletteToken.onSecondaryContainer),
  (PaletteToken.tertiaryContainer, PaletteToken.onTertiaryContainer),
  (PaletteToken.errorContainer, PaletteToken.onErrorContainer),
  (PaletteToken.successContainer, PaletteToken.onSuccessContainer),
  (PaletteToken.warningContainer, PaletteToken.onWarningContainer),
  (PaletteToken.infoContainer, PaletteToken.onInfoContainer),
];

// Tokens the first contrast pass covers, before containers and on-colors
// exist.
const _firstPass = {
  PaletteToken.text,
  PaletteToken.textSecondary,
  PaletteToken.textTertiary,
  PaletteToken.border,
  PaletteToken.primary,
  PaletteToken.secondary,
  PaletteToken.tertiary,
  PaletteToken.error,
  PaletteToken.success,
  PaletteToken.warning,
  PaletteToken.info,
};

/// The hue and chroma derived greys are tinted with.
class _Tint {
  _Tint(this.hue, Brightness brightness, DarkStyle style, {required bool grey})
    : surfaceChroma = grey
          ? 0
          : brightness == Brightness.light
          ? 0.004
          : (style.surfaces == DarkSurfaces.tinted ? 0.012 : 0),
      contentChroma = grey
          ? 0
          : (brightness == Brightness.light ||
                    style.surfaces == DarkSurfaces.tinted
                ? 0.008
                : 0);

  final double hue;
  final double surfaceChroma;
  final double contentChroma;
}

ResolvedPalette _resolve(
  Brightness brightness,
  List<Color?> own,
  List<Color?> other,
  Color? neutral,
  DarkStyle style,
) {
  final dark = brightness == Brightness.dark;
  final v = List<Color?>.of(own);
  final derived = List<bool>.filled(_n, false);

  Color at(PaletteToken t) => v[t.index]!;
  bool isSet(PaletteToken t) => v[t.index] != null;
  Color? fromOther(PaletteToken t) => other[t.index];
  void derive(PaletteToken t, Color color) {
    v[t.index] = color;
    derived[t.index] = true;
  }

  void fix(PaletteToken fg, List<PaletteToken> backgrounds, double minimum) {
    if (!derived[fg.index]) return;
    var color = at(fg);
    // Two passes: moving away from one background can't hurt another on the
    // same side, but a second pass makes that certain.
    for (var pass = 0; pass < 2; pass++) {
      for (final bg in backgrounds) {
        color = ensureContrast(color, at(bg), minimum);
      }
    }
    v[fg.index] = color;
  }

  // Everything keys off primary, so it comes first.
  if (!isSet(PaletteToken.primary)) {
    final o = fromOther(PaletteToken.primary);
    if (o == null) {
      throw ArgumentError(
        'Give a primary color, a seed or a base theme for the light or the '
        'dark palette.',
      );
    }
    derive(PaletteToken.primary, retoneAccent(o, brightness, style));
  }
  final primary = Oklch.fromColor(at(PaletteToken.primary));
  final tint = _Tint(
    neutral != null ? Oklch.fromColor(neutral).h : primary.h,
    brightness,
    style,
    grey: neutral == null && primary.c < 0.02,
  );
  final targets = !dark
      ? _lightL
      : (style.surfaces == DarkSurfaces.black ? _blackL : _darkL);

  // Surfaces, content and lines.
  for (final t in _lightL.keys) {
    if (isSet(t)) continue;
    final surface = _surfaceTokens.contains(t);
    final o = fromOther(t);
    if (o != null) {
      final src = Oklch.fromColor(o);
      final greyFill = dark && style.surfaces != DarkSurfaces.tinted && surface;
      final chromatic = src.c >= 0.01;
      derive(
        t,
        Oklch(
          targets[t]!,
          greyFill
              ? 0
              : chromatic
              ? math.min(src.c, surface ? (dark ? 0.025 : 0.03) : 0.02)
              : (surface ? tint.surfaceChroma : tint.contentChroma),
          chromatic && !greyFill ? src.h : tint.hue,
          src.alpha,
        ).toColor(),
      );
    } else {
      derive(
        t,
        Oklch(
          targets[t]!,
          surface ? tint.surfaceChroma : tint.contentChroma,
          tint.hue,
        ).toColor(),
      );
    }
  }

  // Brand and status colors.
  for (final (t, hueShift, chromaScale) in const [
    (PaletteToken.secondary, 0.0, 0.35),
    (PaletteToken.tertiary, 60.0, 0.6),
  ]) {
    if (isSet(t)) continue;
    final o = fromOther(t);
    if (o != null) {
      derive(t, retoneAccent(o, brightness, style));
      continue;
    }
    final l = dark ? primary.l : primary.l.clamp(0.40, 0.60);
    final c = primary.c < 0.02
        ? primary.c
        : math.max(primary.c * chromaScale, 0.02);
    derive(t, Oklch(l, c, (primary.h + hueShift) % 360).toColor());
  }
  for (final entry in _statusLight.entries) {
    if (isSet(entry.key)) continue;
    final o = fromOther(entry.key);
    derive(
      entry.key,
      o != null
          ? retoneAccent(o, brightness, style)
          : (dark ? retoneAccent(entry.value, brightness, style) : entry.value),
    );
  }
  if (!isSet(PaletteToken.scrim)) {
    derive(
      PaletteToken.scrim,
      fromOther(PaletteToken.scrim) ?? const Color(0x8A000000),
    );
  }
  if (!isSet(PaletteToken.shadow)) {
    derive(
      PaletteToken.shadow,
      fromOther(PaletteToken.shadow) ?? const Color(0xFF000000),
    );
  }

  for (final rule in contrastRules) {
    if (_firstPass.contains(rule.foreground)) {
      fix(rule.foreground, rule.backgrounds, rule.minimum);
    }
  }

  // Link and focus follow primary unless set.
  for (final t in const [PaletteToken.link, PaletteToken.focus]) {
    if (isSet(t)) continue;
    final o = fromOther(t);
    derive(
      t,
      o != null ? retoneAccent(o, brightness, style) : at(PaletteToken.primary),
    );
  }

  // Containers, then the colors drawn on everything.
  for (final (base, container) in _containers) {
    if (isSet(container)) continue;
    final o = fromOther(container);
    final src = Oklch.fromColor(o ?? at(base));
    final c = o != null
        ? math.min(src.c, dark ? 0.09 : 0.05)
        : math.min(src.c * (dark ? 0.6 : 0.35), dark ? 0.09 : 0.05);
    derive(container, Oklch(dark ? 0.32 : 0.94, c, src.h, src.alpha).toColor());
  }
  for (final (base, on) in _onColors) {
    if (!isSet(on)) derive(on, bestOn(at(base)));
  }
  for (final (container, on) in _onContainers) {
    if (isSet(on)) continue;
    final src = Oklch.fromColor(at(container));
    derive(
      on,
      dark
          ? Oklch(0.92, math.min(src.c * 0.5, 0.04), src.h).toColor()
          : Oklch(0.30, math.min(src.c * 2, 0.10), src.h).toColor(),
    );
  }

  for (final rule in contrastRules) {
    if (!_firstPass.contains(rule.foreground)) {
      fix(rule.foreground, rule.backgrounds, rule.minimum);
    }
  }

  // Effects follow the text and primary colors of this palette.
  if (!isSet(PaletteToken.textDisabled)) {
    derive(
      PaletteToken.textDisabled,
      at(PaletteToken.text).withValues(alpha: 0.38),
    );
  }
  if (!isSet(PaletteToken.overlay)) {
    derive(PaletteToken.overlay, at(PaletteToken.text).withValues(alpha: 0.08));
  }
  if (!isSet(PaletteToken.selection)) {
    derive(
      PaletteToken.selection,
      at(PaletteToken.primary).withValues(alpha: 0.4),
    );
  }

  return ResolvedPalette.fromList(brightness, [
    for (final color in v) color!,
  ], style: style);
}
