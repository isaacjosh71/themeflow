import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../color/contrast.dart';
import '../palette/dark_style.dart';
import '../palette/derive.dart';
import '../palette/palette_scope.dart';
import '../palette/resolved_palette.dart';
import '../palette/theme_palette.dart';
import '../state/controller.dart';
import '../state/theme_mode_state.dart';
import '../theme/color_scheme.dart';
import '../theme/generate.dart';
import '../theme/recolor.dart';
import 'labels.dart';

/// Builds your app widget with the themes [ThemeFlow] made.
typedef ThemeFlowWidgetBuilder =
    Widget Function(BuildContext context, ThemeFlowThemes theme);

/// The themes [ThemeFlow] built, ready for your app widget.
@immutable
class ThemeFlowThemes {
  /// Creates a set of themes.
  const ThemeFlowThemes({
    required this.light,
    required this.dark,
    required this.mode,
    required this.brightness,
    required this.palettes,
  });

  /// Pass this to `MaterialApp.theme`.
  final ThemeData light;

  /// Pass this to `MaterialApp.darkTheme`.
  final ThemeData dark;

  /// Pass this to `MaterialApp.themeMode`.
  final ThemeMode mode;

  /// The brightness on screen.
  final Brightness brightness;

  /// The light and dark palettes.
  final ResolvedPalettes palettes;

  /// The palette on screen.
  ResolvedPalette get palette => palettes.of(brightness);

  /// The theme on screen.
  ThemeData get current => brightness == Brightness.dark ? dark : light;

  /// A theme for `CupertinoApp`, which has no separate dark theme. Pass it
  /// as `CupertinoApp(theme: t.cupertino)`.
  CupertinoThemeData get cupertino => cupertinoThemeFromPalette(palette);
}

/// Gives your app a light and a dark theme, keeps the user's choice, and
/// lets any widget below switch it.
///
/// **New app:** give a palette. Dark is derived.
///
/// ```dart
/// ThemeFlow(
///   controller: theme,
///   light: const ThemePalette(primary: Color(0xFF3D5AFE)),
///   builder: (context, t) => MaterialApp(
///     theme: t.light,
///     darkTheme: t.dark,
///     themeMode: t.mode,
///     home: const HomePage(),
///   ),
/// );
/// ```
///
/// **Existing app:** give your theme as [base]. Light mode shows exactly
/// that theme. Dark mode is the same theme, recolored, with your fonts,
/// shapes and spacing kept.
///
/// ```dart
/// ThemeFlow(
///   controller: theme,
///   base: AppTheme.light,
///   builder: (context, t) => MaterialApp.router(
///     theme: t.light,
///     darkTheme: t.dark,
///     themeMode: t.mode,
///     routerConfig: router,
///   ),
/// );
/// ```
///
/// The mode comes from a [controller], or from your own state through
/// [mode] and [onModeChanged]. With neither, ThemeFlow makes its own
/// controller that saves the choice with `shared_preferences`.
class ThemeFlow extends StatefulWidget {
  /// Creates a ThemeFlow.
  const ThemeFlow({
    super.key,
    this.controller,
    this.mode,
    this.onModeChanged,
    this.light,
    this.dark,
    this.base,
    this.darkBase,
    this.darkExtensions = const [],
    this.darkStyle = const DarkStyle(),
    this.enabled = true,
    this.systemBars = true,
    this.deferFirstFrame = false,
    this.contrastWarnings = true,
    this.labels = const ThemeFlowLabels(),
    required this.builder,
  }) : assert(
         controller == null || mode == null,
         'Pass either a controller or a mode, not both.',
       );

  /// Holds and saves the user's choice. Leave null to use [mode], or to let
  /// ThemeFlow make its own.
  final ThemeFlowController? controller;

  /// The mode, when it lives in your own state (controlled mode).
  final ThemeMode? mode;

  /// Called when a toggle picks a mode in controlled mode.
  final ValueChanged<ThemeMode>? onModeChanged;

  /// Your light colors. With a [base], they're applied on top of the colors
  /// read from it.
  final ThemePalette? light;

  /// Your dark colors, as overrides on top of the derived dark palette. It
  /// can be as small as one color.
  final ThemePalette? dark;

  /// Your existing theme. Light mode uses it as it is; dark mode is it,
  /// recolored. If it's a dark theme, light mode is derived instead.
  final ThemeData? base;

  /// Your own dark theme, used as it is instead of recoloring [base].
  final ThemeData? darkBase;

  /// Dark versions of your own theme extensions. Each replaces the one of
  /// the same type in the dark theme.
  final List<ThemeExtension<dynamic>> darkExtensions;

  /// How dark colors are derived.
  final DarkStyle darkStyle;

  /// When false, the app always shows its light theme and the toggles hide.
  /// Handy for rolling dark mode out behind a flag.
  final bool enabled;

  /// Whether to style the status and navigation bars to match the theme on
  /// screens without an app bar. Turn it off if you set `SystemChrome`
  /// styles yourself.
  final bool systemBars;

  /// Whether to hold the first frame (keeping the native splash up) until
  /// the saved choice is read, for at most 500 ms. Not needed if you call
  /// `await controller.load()` before `runApp`.
  final bool deferFirstFrame;

  /// Whether to print hard-to-read color pairs in debug builds.
  final bool contrastWarnings;

  /// The text the toggles show.
  final ThemeFlowLabels labels;

  /// Builds your app widget.
  final ThemeFlowWidgetBuilder builder;

  /// The theme mode controls of the nearest ThemeFlow.
  ///
  /// Widgets that call this rebuild when the mode changes.
  static ThemeModeState of(BuildContext context) => _scope(context).state;

  /// Like [of], but returns null when there's no ThemeFlow above.
  static ThemeModeState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeFlowScope>()?.state;

  /// The themes of the nearest ThemeFlow.
  static ThemeFlowThemes themesOf(BuildContext context) =>
      _scope(context).themes;

  /// The toggle labels of the nearest ThemeFlow, or the English defaults.
  static ThemeFlowLabels labelsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeFlowScope>()?.labels ??
      const ThemeFlowLabels();

  static _ThemeFlowScope _scope(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ThemeFlowScope>();
    if (scope != null) return scope;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('No ThemeFlow found in this context.'),
      ErrorHint('Wrap your app widget in ThemeFlow(...).'),
    ]);
  }

  @override
  State<ThemeFlow> createState() => _ThemeFlowState();
}

class _ThemeFlowState extends State<ThemeFlow> with WidgetsBindingObserver {
  ThemeFlowController? _own;
  late Brightness _platform;
  _Built? _built;
  bool _holdingFirstFrame = false;
  Timer? _firstFrameTimer;

  ThemeFlowController? get _controller =>
      widget.mode != null ? null : (widget.controller ?? _own);

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _platform = binding.platformDispatcher.platformBrightness;
    if (widget.controller == null && widget.mode == null) {
      _own = ThemeFlowController();
    }
    _attach(_controller);
  }

  void _attach(ThemeFlowController? controller) {
    if (controller == null) return;
    controller.addListener(_changed);
    if (controller.isLoaded) return;
    if (widget.deferFirstFrame &&
        !WidgetsBinding.instance.firstFrameRasterized) {
      WidgetsBinding.instance.deferFirstFrame();
      _holdingFirstFrame = true;
      _firstFrameTimer = Timer(
        const Duration(milliseconds: 500),
        _releaseFirstFrame,
      );
    }
    unawaited(controller.load().whenComplete(_releaseFirstFrame));
  }

  void _releaseFirstFrame() {
    if (!_holdingFirstFrame) return;
    _holdingFirstFrame = false;
    _firstFrameTimer?.cancel();
    WidgetsBinding.instance.allowFirstFrame();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ThemeFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.mode != null
        ? null
        : (oldWidget.controller ?? _own);
    if (widget.controller == null && widget.mode == null && _own == null) {
      _own = ThemeFlowController();
    }
    final controller = _controller;
    if (!identical(oldController, controller)) {
      oldController?.removeListener(_changed);
      _attach(controller);
    }
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_changed);
    _releaseFirstFrame();
    _own?.dispose();
    super.dispose();
  }

  void _setMode(ThemeMode mode) {
    final controller = _controller;
    if (controller != null) {
      controller.setMode(mode);
    } else {
      widget.onModeChanged?.call(mode);
    }
  }

  _Built _themes() {
    final config = _Config(widget);
    final cached = _built;
    if (cached != null && cached.config == config) return cached;
    final built = _Built.from(config);
    _built = built;
    _warnAboutContrast(built.palettes);
    return built;
  }

  void _warnAboutContrast(ResolvedPalettes palettes) {
    if (!kDebugMode || !widget.contrastWarnings) return;
    for (final palette in [palettes.light, palettes.dark]) {
      final failures = palette.contrastReport().failures;
      if (failures.isEmpty) continue;
      final lines = [
        for (final f in failures)
          '  $f. Nearest passing: ${_hex(ensureContrast(palette[f.foreground], palette[f.background], f.minimum))}',
      ];
      debugPrint(
        'themeflow: some ${palette.brightness.name} colors are hard to read:\n'
        '${lines.join('\n')}\n'
        '  These are colors you set, which themeflow never changes. '
        'Hide this with ThemeFlow(contrastWarnings: false).',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final built = _themes();
    final enabled = widget.enabled;
    final chosen = widget.mode ?? _controller!.mode;
    final mode = enabled ? chosen : ThemeMode.light;
    final brightness = brightnessFor(mode, _platform);
    final themes = ThemeFlowThemes(
      light: built.light,
      dark: enabled ? built.dark : built.light,
      mode: mode,
      brightness: brightness,
      palettes: built.palettes,
    );
    final state = _ModeSnapshot(
      mode: mode,
      brightness: brightness,
      enabled: enabled,
      onMode: _setMode,
    );

    Widget child = widget.builder(context, themes);
    if (widget.systemBars) {
      child = AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemBarsStyle(
          themes.palette,
          base: themes.current.appBarTheme.systemOverlayStyle,
        ),
        child: child,
      );
    }
    return _ThemeFlowScope(
      state: state,
      themes: themes,
      labels: widget.labels,
      child: PaletteScope(palette: themes.palette, child: child),
    );
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The inputs themes are built from. Themes are rebuilt only when these
/// change.
@immutable
class _Config {
  _Config(ThemeFlow w)
    : light = w.light,
      dark = w.dark,
      base = w.base,
      darkBase = w.darkBase,
      darkExtensions = w.darkExtensions,
      style = w.darkStyle;

  final ThemePalette? light;
  final ThemePalette? dark;
  final ThemeData? base;
  final ThemeData? darkBase;
  final List<ThemeExtension<dynamic>> darkExtensions;
  final DarkStyle style;

  static bool _same(ThemeData? a, ThemeData? b) => identical(a, b) || a == b;

  @override
  bool operator ==(Object other) =>
      other is _Config &&
      other.light == light &&
      other.dark == dark &&
      _same(other.base, base) &&
      _same(other.darkBase, darkBase) &&
      listEquals(other.darkExtensions, darkExtensions) &&
      other.style == style;

  @override
  int get hashCode => Object.hash(light, dark, base, darkBase, style);
}

@immutable
class _Built {
  const _Built(this.config, this.palettes, this.light, this.dark);

  factory _Built.from(_Config c) {
    final base = c.base;
    final darkBase = c.darkBase;
    final style = c.style;

    if (base == null) {
      final ThemePalette? light = c.light;
      var dark = c.dark;
      if (darkBase != null) dark = ThemePalette.fromTheme(darkBase).merge(dark);
      if (light == null && dark == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('ThemeFlow needs colors to work with.'),
          ErrorHint(
            'Pass a palette (light: ThemePalette(primary: ...)) or your '
            'existing theme (base: AppTheme.light).',
          ),
        ]);
      }
      final palettes = resolvePalettes(light: light, dark: dark, style: style);
      return _Built(
        c,
        palettes,
        generateTheme(palettes.light),
        darkBase != null
            ? _withPalette(darkBase, palettes.dark, c.darkExtensions)
            : _withPalette(
                generateTheme(palettes.dark),
                palettes.dark,
                c.darkExtensions,
              ),
      );
    }

    final inferred = ThemePalette.fromTheme(base);
    if (base.brightness == Brightness.light) {
      final darkInput = darkBase != null
          ? ThemePalette.fromTheme(darkBase).merge(c.dark)
          : c.dark;
      final palettes = resolvePalettes(
        light: inferred.merge(c.light),
        dark: darkInput,
        style: style,
      );
      // What the base theme's colors actually are, to map them from.
      final from = c.light == null
          ? palettes.light
          : resolvePalettes(
              light: inferred,
              dark: darkInput,
              style: style,
            ).light;
      return _Built(
        c,
        palettes,
        c.light == null
            ? _withPalette(base, palettes.light, const [])
            : recolor(base, from: from, to: palettes.light),
        darkBase != null
            ? _withPalette(darkBase, palettes.dark, c.darkExtensions)
            : recolor(
                base,
                from: from,
                to: palettes.dark,
                extensions: c.darkExtensions,
              ),
      );
    }

    // A dark-first app: the base is the dark theme and light is derived.
    final palettes = resolvePalettes(
      light: c.light,
      dark: inferred.merge(c.dark),
      style: style,
    );
    final from = c.dark == null
        ? palettes.dark
        : resolvePalettes(light: c.light, dark: inferred, style: style).dark;
    return _Built(
      c,
      palettes,
      recolor(base, from: from, to: palettes.light),
      c.dark == null
          ? _withPalette(base, palettes.dark, c.darkExtensions)
          : recolor(
              base,
              from: from,
              to: palettes.dark,
              extensions: c.darkExtensions,
            ),
    );
  }

  final _Config config;
  final ResolvedPalettes palettes;
  final ThemeData light;
  final ThemeData dark;

  static ThemeData _withPalette(
    ThemeData theme,
    ResolvedPalette palette,
    List<ThemeExtension<dynamic>> extensions,
  ) {
    // Same cast Flutter's own ThemeData uses: ThemeExtension is F-bounded.
    final byType = <Object, ThemeExtension<ThemeExtension<dynamic>>>{};
    void put(ThemeExtension<dynamic> e) =>
        byType[e.type] = e as ThemeExtension<ThemeExtension<dynamic>>;
    for (final e in theme.extensions.values) {
      if (e is! ResolvedPalette) put(e);
    }
    extensions.forEach(put);
    put(palette);
    return theme.copyWith(extensions: byType.values);
  }
}

@immutable
class _ModeSnapshot implements ThemeModeState {
  const _ModeSnapshot({
    required this.mode,
    required this.brightness,
    required this.enabled,
    required this.onMode,
  });

  @override
  final ThemeMode mode;

  @override
  final Brightness brightness;

  @override
  final bool enabled;

  final ValueChanged<ThemeMode> onMode;

  @override
  bool get isDark => brightness == Brightness.dark;

  @override
  void setMode(ThemeMode mode) {
    if (enabled) onMode(mode);
  }

  @override
  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  @override
  void cycle() => setMode(nextThemeMode(mode));

  @override
  bool operator ==(Object other) =>
      other is _ModeSnapshot &&
      other.mode == mode &&
      other.brightness == brightness &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(mode, brightness, enabled);
}

class _ThemeFlowScope extends InheritedWidget {
  const _ThemeFlowScope({
    required this.state,
    required this.themes,
    required this.labels,
    required super.child,
  });

  final _ModeSnapshot state;
  final ThemeFlowThemes themes;
  final ThemeFlowLabels labels;

  @override
  bool updateShouldNotify(_ThemeFlowScope oldWidget) =>
      state != oldWidget.state ||
      !identical(themes.light, oldWidget.themes.light) ||
      !identical(themes.dark, oldWidget.themes.dark) ||
      labels != oldWidget.labels;
}
