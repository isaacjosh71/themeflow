import 'package:flutter/material.dart';

import '../palette/color_token.dart';
import '../palette/palette_scope.dart';
import '../palette/resolved_palette.dart';
import '../theme/recolor.dart';
import 'context.dart';
import 'theme_flow.dart';

/// Shows [child] in the dark or light theme, whatever the mode.
///
/// For parts of a screen that should always look one way: a video player, a
/// photo viewer, an onboarding hero.
///
/// ```dart
/// ForceBrightness.dark(child: VideoControls());
/// ```
class ForceBrightness extends StatelessWidget {
  /// Shows [child] in the [brightness] theme.
  const ForceBrightness({
    super.key,
    required this.brightness,
    required this.child,
  });

  /// Shows [child] in the dark theme.
  const ForceBrightness.dark({super.key, required this.child})
    : brightness = Brightness.dark;

  /// Shows [child] in the light theme.
  const ForceBrightness.light({super.key, required this.child})
    : brightness = Brightness.light;

  /// The brightness to show.
  final Brightness brightness;

  /// The subtree to show in it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final themes = ThemeFlow.themesOf(context);
    return Theme(
      data: brightness == Brightness.dark ? themes.dark : themes.light,
      child: PaletteScope(
        palette: themes.palettes.of(brightness),
        // Sets the default text style from the new theme.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// Changes palette colors for [child] and everything below it.
///
/// Material widgets inside follow too, because the theme is recolored with
/// the new palette.
///
/// ```dart
/// PaletteOverride(
///   colors: {AppColors.gold: Colors.amber},
///   update: (p) => p.copyWith(surface: const Color(0xFFFFF8E1)),
///   child: PromoBanner(),
/// );
/// ```
class PaletteOverride extends StatefulWidget {
  /// Creates an override.
  const PaletteOverride({
    super.key,
    this.colors = const {},
    this.update,
    required this.child,
  });

  /// New values for your own tokens.
  final Map<ColorToken, Color> colors;

  /// Changes built-in tokens, typically with `palette.copyWith(...)`.
  final ResolvedPalette Function(ResolvedPalette palette)? update;

  /// The subtree that sees the changed palette.
  final Widget child;

  @override
  State<PaletteOverride> createState() => _PaletteOverrideState();
}

class _PaletteOverrideState extends State<PaletteOverride> {
  ThemeData? _source;
  ResolvedPalette? _next;
  ThemeData? _result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    var next = widget.update?.call(palette) ?? palette;
    if (widget.colors.isNotEmpty) next = next.withTokens(widget.colors);
    if (!identical(theme, _source) || next != _next || _result == null) {
      _source = theme;
      _next = next;
      _result = recolor(theme, from: palette, to: next);
    }
    return Theme(
      data: _result!,
      child: PaletteScope(palette: next, child: widget.child),
    );
  }
}
