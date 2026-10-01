/// Dark mode for an existing Flutter app in an afternoon.
///
/// Keep your light theme, get a contrast-checked dark one, read typed color
/// tokens anywhere, and let users switch with ready-made toggles.
///
/// ```dart
/// ThemeFlow(
///   controller: theme,
///   base: AppTheme.light, // your current ThemeData, untouched in light mode
///   builder: (context, t) => MaterialApp(
///     theme: t.light,
///     darkTheme: t.dark,
///     themeMode: t.mode,
///   ),
/// );
/// ```
library;

export 'src/color/contrast.dart' show contrastRatio;
export 'src/palette/color_token.dart';
export 'src/palette/contrast_report.dart'
    show ContrastCheck, ContrastReport, ContrastRule, contrastRules;
export 'src/palette/dark_style.dart';
export 'src/palette/derive.dart' show ResolvedPalettes, resolvePalettes;
export 'src/palette/palette_token.dart';
export 'src/palette/resolved_palette.dart';
export 'src/palette/theme_palette.dart';
export 'src/state/controller.dart';
export 'src/state/storage.dart';
export 'src/state/theme_mode_state.dart' show ThemeModeState;
export 'src/theme/color_scheme.dart' show schemeFromPalette;
export 'src/theme/generate.dart';
export 'src/theme/recolor.dart';
export 'src/widgets/context.dart';
export 'src/widgets/labels.dart';
export 'src/widgets/overrides.dart';
export 'src/widgets/theme_flow.dart';
export 'src/widgets/themed_image.dart';
export 'src/widgets/toggles.dart';
