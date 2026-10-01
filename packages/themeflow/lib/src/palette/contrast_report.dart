import 'package:flutter/foundation.dart';

import '../color/contrast.dart';
import 'palette_token.dart';
import 'resolved_palette.dart';

/// A foreground token, the backgrounds it has to read on, and the minimum
/// WCAG 2.2 contrast ratio.
typedef ContrastRule = ({
  PaletteToken foreground,
  List<PaletteToken> backgrounds,
  double minimum,
});

const _allSurfaces = [
  PaletteToken.background,
  PaletteToken.surface,
  PaletteToken.surfaceElevated,
  PaletteToken.fill,
];
const _baseSurfaces = [PaletteToken.background, PaletteToken.surface];

/// The pairs themeflow checks, and enforces on the colors it derives.
///
/// * Text, secondary text and links: 4.5:1.
/// * Text and icons on a color (`on…`): 4.5:1.
/// * Tertiary text, borders, brand and status colors: 3:1, the WCAG minimum
///   for non-essential text and UI components.
/// * Dividers and disabled colors are exempt.
const List<ContrastRule> contrastRules = [
  (foreground: PaletteToken.text, backgrounds: _allSurfaces, minimum: 4.5),
  (
    foreground: PaletteToken.textSecondary,
    backgrounds: _allSurfaces,
    minimum: 4.5,
  ),
  (foreground: PaletteToken.link, backgrounds: _baseSurfaces, minimum: 4.5),
  (
    foreground: PaletteToken.textTertiary,
    backgrounds: _baseSurfaces,
    minimum: 3,
  ),
  (foreground: PaletteToken.border, backgrounds: _baseSurfaces, minimum: 3),
  (foreground: PaletteToken.primary, backgrounds: _baseSurfaces, minimum: 3),
  (foreground: PaletteToken.secondary, backgrounds: _baseSurfaces, minimum: 3),
  (foreground: PaletteToken.tertiary, backgrounds: _baseSurfaces, minimum: 3),
  (foreground: PaletteToken.error, backgrounds: _baseSurfaces, minimum: 3),
  (foreground: PaletteToken.success, backgrounds: _baseSurfaces, minimum: 3),
  (foreground: PaletteToken.warning, backgrounds: _baseSurfaces, minimum: 3),
  (foreground: PaletteToken.info, backgrounds: _baseSurfaces, minimum: 3),
  (
    foreground: PaletteToken.onPrimary,
    backgrounds: [PaletteToken.primary],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onSecondary,
    backgrounds: [PaletteToken.secondary],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onTertiary,
    backgrounds: [PaletteToken.tertiary],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onError,
    backgrounds: [PaletteToken.error],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onSuccess,
    backgrounds: [PaletteToken.success],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onWarning,
    backgrounds: [PaletteToken.warning],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onInfo,
    backgrounds: [PaletteToken.info],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onInverseSurface,
    backgrounds: [PaletteToken.inverseSurface],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onPrimaryContainer,
    backgrounds: [PaletteToken.primaryContainer],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onSecondaryContainer,
    backgrounds: [PaletteToken.secondaryContainer],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onTertiaryContainer,
    backgrounds: [PaletteToken.tertiaryContainer],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onErrorContainer,
    backgrounds: [PaletteToken.errorContainer],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onSuccessContainer,
    backgrounds: [PaletteToken.successContainer],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onWarningContainer,
    backgrounds: [PaletteToken.warningContainer],
    minimum: 4.5,
  ),
  (
    foreground: PaletteToken.onInfoContainer,
    backgrounds: [PaletteToken.infoContainer],
    minimum: 4.5,
  ),
];

/// One foreground/background pair and how it measures up.
@immutable
class ContrastCheck {
  /// Creates a check result.
  const ContrastCheck({
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.minimum,
  });

  /// The token drawn on top.
  final PaletteToken foreground;

  /// The token it's drawn on.
  final PaletteToken background;

  /// The measured WCAG 2 contrast ratio, from 1 to 21.
  final double ratio;

  /// The ratio this pair needs.
  final double minimum;

  /// Whether [ratio] meets [minimum].
  bool get passes => ratio + 1e-9 >= minimum;

  @override
  String toString() =>
      '${foreground.name} on ${background.name}: '
      '${ratio.toStringAsFixed(2)}:1, needs ${_format(minimum)}:1';
}

/// How well a palette's foreground/background pairs read.
@immutable
class ContrastReport {
  const ContrastReport._(this.brightness, this.checks);

  /// Checks every rule in [contrastRules] against [palette].
  factory ContrastReport.of(ResolvedPalette palette) => ContrastReport._(
    palette.brightness,
    List<ContrastCheck>.unmodifiable([
      for (final rule in contrastRules)
        for (final background in rule.backgrounds)
          ContrastCheck(
            foreground: rule.foreground,
            background: background,
            ratio: contrastRatio(palette[rule.foreground], palette[background]),
            minimum: rule.minimum,
          ),
    ]),
  );

  /// The brightness of the palette that was checked.
  final Brightness brightness;

  /// Every check, passing or not.
  final List<ContrastCheck> checks;

  /// The checks that fall short of their minimum.
  List<ContrastCheck> get failures => [
    for (final check in checks)
      if (!check.passes) check,
  ];

  @override
  String toString() {
    final failed = failures;
    if (failed.isEmpty) return 'ContrastReport(${brightness.name}: all pass)';
    return 'ContrastReport(${brightness.name}: ${failed.join('; ')})';
  }
}

String _format(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
