import 'package:flutter/material.dart';

/// The theme mode, and the ways to change it.
///
/// `ThemeFlow.of(context)`, `context.themeFlow` and `ThemeModeBuilder` give
/// you one of these. [ThemeFlowController] is one too.
abstract interface class ThemeModeState {
  /// The mode the user picked: system, light or dark.
  ThemeMode get mode;

  /// The brightness on screen. In system mode it follows the device.
  Brightness get brightness;

  /// Whether dark is on screen.
  bool get isDark;

  /// Whether switching is available. False when `ThemeFlow(enabled: false)`.
  bool get enabled;

  /// Switches to [mode].
  void setMode(ThemeMode mode);

  /// Switches between light and dark. In system mode it flips what's on
  /// screen.
  void toggle();

  /// Moves to the next mode: system, then light, then dark, then system.
  void cycle();
}

/// The mode after [mode] in [ThemeModeState.cycle] order.
ThemeMode nextThemeMode(ThemeMode mode) => switch (mode) {
  ThemeMode.system => ThemeMode.light,
  ThemeMode.light => ThemeMode.dark,
  ThemeMode.dark => ThemeMode.system,
};

/// The brightness [mode] shows when the device is [platform].
Brightness brightnessFor(ThemeMode mode, Brightness platform) => switch (mode) {
  ThemeMode.light => Brightness.light,
  ThemeMode.dark => Brightness.dark,
  ThemeMode.system => platform,
};
