import 'package:flutter/widgets.dart';

import 'resolved_palette.dart';

/// Provides the current palette to widgets that have no Material `Theme`
/// above them, such as apps built on `CupertinoApp` or `WidgetsApp`.
///
/// `ThemeFlow` inserts one automatically. Inside a Material app the palette
/// is read from the theme instead, so local `Theme` overrides and the theme
/// animation keep working.
class PaletteScope extends InheritedWidget {
  /// Provides [palette] to [child].
  const PaletteScope({super.key, required this.palette, required super.child});

  /// The palette for this part of the tree.
  final ResolvedPalette palette;

  /// The nearest scope's palette, or null.
  static ResolvedPalette? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette;

  @override
  bool updateShouldNotify(PaletteScope oldWidget) =>
      palette != oldWidget.palette;
}
