import 'package:flutter/material.dart';

import '../palette/resolved_palette.dart';
import '../state/theme_mode_state.dart';
import 'theme_flow.dart';

/// Shortcuts for reading the theme.
///
/// If another package in your app also defines `context.palette` or
/// `context.isDark`, use [ResolvedPalette.of] instead, or hide this
/// extension: `import 'package:themeflow/themeflow.dart' hide ThemeFlowContext;`.
extension ThemeFlowContext on BuildContext {
  /// The palette on screen here. Widgets that read it rebuild when the theme
  /// changes.
  ///
  /// ```dart
  /// Container(color: context.palette.surface);
  /// ```
  ResolvedPalette get palette => ResolvedPalette.of(this);

  /// Whether dark is on screen here. It's correct in system mode and inside
  /// `ForceBrightness`.
  bool get isDark =>
      (ResolvedPalette.maybeOf(this)?.brightness ??
          Theme.of(this).brightness) ==
      Brightness.dark;

  /// [light] in light mode and [dark] in dark mode.
  ///
  /// Use it instead of `isDark ? a : b` for one-off values such as images or
  /// animation files.
  T pick<T>({required T light, required T dark}) => isDark ? dark : light;

  /// The theme mode controls of the nearest `ThemeFlow`.
  ///
  /// ```dart
  /// context.themeFlow.setMode(ThemeMode.dark);
  /// ```
  ThemeModeState get themeFlow => ThemeFlow.of(this);
}
