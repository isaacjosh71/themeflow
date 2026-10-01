import 'package:flutter/material.dart';

import '../state/theme_mode_state.dart';
import 'labels.dart';
import 'theme_flow.dart';

/// Builds any control you like from the current theme mode.
///
/// Every themeflow toggle is built on this. Use it to wrap your own design
/// system's switch:
///
/// ```dart
/// ThemeModeBuilder(
///   builder: (context, s) => MyToggle(
///     value: s.isDark,
///     onChanged: (_) => s.toggle(),
///   ),
/// );
/// ```
///
/// When `ThemeFlow(enabled: false)`, it shows nothing unless
/// [showWhenDisabled] is true.
class ThemeModeBuilder extends StatelessWidget {
  /// Creates a builder.
  const ThemeModeBuilder({
    super.key,
    required this.builder,
    this.showWhenDisabled = false,
  });

  /// Builds the control.
  final Widget Function(BuildContext context, ThemeModeState state) builder;

  /// Whether to build even when switching is off.
  final bool showWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final state = ThemeFlow.of(context);
    if (!state.enabled && !showWhenDisabled) return const SizedBox.shrink();
    return builder(context, state);
  }
}

/// A switch for dark mode: on is dark.
///
/// In system mode it shows what's on screen, and flipping it picks light or
/// dark explicitly.
class ThemeModeSwitch extends StatelessWidget {
  /// Creates a switch.
  const ThemeModeSwitch({super.key, this.adaptive = true, this.labels});

  /// Whether to use a Cupertino switch on iOS and macOS.
  final bool adaptive;

  /// Overrides the labels from `ThemeFlow`.
  final ThemeFlowLabels? labels;

  @override
  Widget build(BuildContext context) => ThemeModeBuilder(
    builder: (context, s) {
      void onChanged(bool dark) =>
          s.setMode(dark ? ThemeMode.dark : ThemeMode.light);
      final l = labels ?? ThemeFlow.labelsOf(context);
      return Semantics(
        label: l.darkMode,
        child: adaptive
            ? Switch.adaptive(value: s.isDark, onChanged: onChanged)
            : Switch(value: s.isDark, onChanged: onChanged),
      );
    },
  );
}

/// A settings row with a dark mode switch.
class ThemeModeSwitchTile extends StatelessWidget {
  /// Creates a settings row.
  const ThemeModeSwitchTile({
    super.key,
    this.title,
    this.subtitle,
    this.secondary,
    this.adaptive = true,
    this.labels,
  });

  /// The row title. Defaults to [ThemeFlowLabels.darkMode].
  final Widget? title;

  /// Text below the title.
  final Widget? subtitle;

  /// A widget before the title, usually an icon.
  final Widget? secondary;

  /// Whether to use a Cupertino switch on iOS and macOS.
  final bool adaptive;

  /// Overrides the labels from `ThemeFlow`.
  final ThemeFlowLabels? labels;

  @override
  Widget build(BuildContext context) => ThemeModeBuilder(
    builder: (context, s) {
      void onChanged(bool dark) =>
          s.setMode(dark ? ThemeMode.dark : ThemeMode.light);
      final l = labels ?? ThemeFlow.labelsOf(context);
      final title = this.title ?? Text(l.darkMode);
      return adaptive
          ? SwitchListTile.adaptive(
              value: s.isDark,
              onChanged: onChanged,
              title: title,
              subtitle: subtitle,
              secondary: secondary,
            )
          : SwitchListTile(
              value: s.isDark,
              onChanged: onChanged,
              title: title,
              subtitle: subtitle,
              secondary: secondary,
            );
    },
  );
}

/// An icon button with an animated sun and moon.
///
/// A tap toggles light and dark, or with [cycle], steps through system,
/// light and dark.
class ThemeModeButton extends StatelessWidget {
  /// Creates an icon button.
  const ThemeModeButton({
    super.key,
    this.cycle = false,
    this.lightIcon = Icons.light_mode_outlined,
    this.darkIcon = Icons.dark_mode_outlined,
    this.systemIcon = Icons.brightness_auto_outlined,
    this.tooltip,
    this.labels,
  });

  /// Whether a tap steps through system, light and dark.
  final bool cycle;

  /// The icon in light mode.
  final IconData lightIcon;

  /// The icon in dark mode.
  final IconData darkIcon;

  /// The icon in system mode, when [cycle] is true.
  final IconData systemIcon;

  /// The tooltip. Defaults to [ThemeFlowLabels.switchTheme].
  final String? tooltip;

  /// Overrides the labels from `ThemeFlow`.
  final ThemeFlowLabels? labels;

  @override
  Widget build(BuildContext context) => ThemeModeBuilder(
    builder: (context, s) {
      final l = labels ?? ThemeFlow.labelsOf(context);
      final icon = cycle && s.mode == ThemeMode.system
          ? systemIcon
          : (s.isDark ? darkIcon : lightIcon);
      final animate = !MediaQuery.disableAnimationsOf(context);
      return IconButton(
        tooltip: tooltip ?? l.switchTheme,
        onPressed: cycle ? s.cycle : s.toggle,
        icon: AnimatedSwitcher(
          duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(icon, key: ValueKey<IconData>(icon)),
        ),
      );
    },
  );
}

/// A System / Light / Dark segmented button.
class ThemeModeSegmented extends StatelessWidget {
  /// Creates a segmented button.
  const ThemeModeSegmented({
    super.key,
    this.showIcons = true,
    this.showLabels = true,
    this.labels,
  }) : assert(showIcons || showLabels, 'Show icons, labels or both.');

  /// Whether segments have icons.
  final bool showIcons;

  /// Whether segments have labels.
  final bool showLabels;

  /// Overrides the labels from `ThemeFlow`.
  final ThemeFlowLabels? labels;

  @override
  Widget build(BuildContext context) => ThemeModeBuilder(
    builder: (context, s) {
      final l = labels ?? ThemeFlow.labelsOf(context);
      return SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        selected: {s.mode},
        onSelectionChanged: (selected) => s.setMode(selected.first),
        segments: [
          for (final mode in ThemeMode.values)
            ButtonSegment<ThemeMode>(
              value: mode,
              tooltip: showLabels ? null : l.of(mode),
              icon: showIcons ? Icon(_iconFor(mode)) : null,
              label: showLabels ? Text(l.of(mode)) : null,
            ),
        ],
      );
    },
  );
}

/// A radio list of System, Light and Dark, for settings screens.
class ThemeModeRadios extends StatelessWidget {
  /// Creates a radio list.
  const ThemeModeRadios({super.key, this.showSystemHint = true, this.labels});

  /// Whether the System row explains that it follows the device.
  final bool showSystemHint;

  /// Overrides the labels from `ThemeFlow`.
  final ThemeFlowLabels? labels;

  @override
  Widget build(BuildContext context) => ThemeModeBuilder(
    builder: (context, s) {
      final l = labels ?? ThemeFlow.labelsOf(context);
      return RadioGroup<ThemeMode>(
        groupValue: s.mode,
        onChanged: (mode) {
          if (mode != null) s.setMode(mode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                value: mode,
                title: Text(l.of(mode)),
                subtitle: showSystemHint && mode == ThemeMode.system
                    ? Text(l.systemHint)
                    : null,
              ),
          ],
        ),
      );
    },
  );
}

/// An icon button that opens a System / Light / Dark menu.
class ThemeModeMenu extends StatelessWidget {
  /// Creates a menu button.
  const ThemeModeMenu({super.key, this.tooltip, this.labels});

  /// The tooltip. Defaults to [ThemeFlowLabels.switchTheme].
  final String? tooltip;

  /// Overrides the labels from `ThemeFlow`.
  final ThemeFlowLabels? labels;

  @override
  Widget build(BuildContext context) => ThemeModeBuilder(
    builder: (context, s) {
      final l = labels ?? ThemeFlow.labelsOf(context);
      return PopupMenuButton<ThemeMode>(
        tooltip: tooltip ?? l.switchTheme,
        initialValue: s.mode,
        onSelected: s.setMode,
        icon: Icon(_iconFor(s.mode)),
        itemBuilder: (context) => [
          for (final mode in ThemeMode.values)
            CheckedPopupMenuItem<ThemeMode>(
              value: mode,
              checked: s.mode == mode,
              child: Text(l.of(mode)),
            ),
        ],
      );
    },
  );
}

IconData _iconFor(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};
