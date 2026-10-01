import 'package:flutter/material.dart';

import '../palette/resolved_palette.dart';
import 'color_scheme.dart';

/// Builds a complete Material 3 [ThemeData] from [palette].
///
/// The [ColorScheme] carries most of it. A handful of component themes whose
/// Material defaults don't match the tokens are set as well: input hints,
/// text selection, dialog and sheet barriers. The palette itself is added as
/// a [ThemeExtension], so `context.palette` works everywhere below.
///
/// Fonts and shapes are Flutter's defaults. To keep your own, pass your theme
/// to `ThemeFlow(base: ...)`, which recolors it instead.
ThemeData generateTheme(ResolvedPalette palette) {
  final p = palette;
  return ThemeData(
    useMaterial3: true,
    colorScheme: schemeFromPalette(p),
    scaffoldBackgroundColor: p.background,
    canvasColor: p.surface,
    cardColor: p.surface,
    dividerColor: p.divider,
    disabledColor: p.textDisabled,
    hintColor: p.textTertiary,
    shadowColor: p.shadow,
    iconTheme: IconThemeData(color: p.text),
    cardTheme: CardThemeData(color: p.surface),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surfaceElevated,
      barrierColor: p.scrim,
    ),
    bottomSheetTheme: BottomSheetThemeData(modalBarrierColor: p.scrim),
    dividerTheme: DividerThemeData(color: p.divider),
    inputDecorationTheme: InputDecorationThemeData(
      fillColor: p.fill,
      hintStyle: TextStyle(color: p.textTertiary),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.selection,
      selectionHandleColor: p.primary,
    ),
    extensions: [p],
  );
}
