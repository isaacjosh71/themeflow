import 'package:flutter/material.dart';

/// The text themeflow's toggles show. English by default.
///
/// ```dart
/// ThemeFlow(
///   labels: const ThemeFlowLabels(
///     system: 'Système',
///     light: 'Clair',
///     dark: 'Sombre',
///     darkMode: 'Mode sombre',
///   ),
///   ...
/// );
/// ```
@immutable
class ThemeFlowLabels {
  /// Creates a set of labels.
  const ThemeFlowLabels({
    this.system = 'System',
    this.light = 'Light',
    this.dark = 'Dark',
    this.darkMode = 'Dark mode',
    this.systemHint = 'Follows your device settings',
    this.switchTheme = 'Switch theme',
  });

  /// The system option.
  final String system;

  /// The light option.
  final String light;

  /// The dark option.
  final String dark;

  /// The label of switches.
  final String darkMode;

  /// The subtitle of the system option in radio lists.
  final String systemHint;

  /// The tooltip of the icon button and the menu.
  final String switchTheme;

  /// The label for [mode].
  String of(ThemeMode mode) => switch (mode) {
    ThemeMode.system => system,
    ThemeMode.light => light,
    ThemeMode.dark => dark,
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeFlowLabels &&
      other.system == system &&
      other.light == light &&
      other.dark == dark &&
      other.darkMode == darkMode &&
      other.systemHint == systemHint &&
      other.switchTheme == switchTheme;

  @override
  int get hashCode =>
      Object.hash(system, light, dark, darkMode, systemHint, switchTheme);
}
