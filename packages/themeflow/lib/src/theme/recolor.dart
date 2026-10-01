import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../color/contrast.dart';
import '../color/oklch.dart';
import '../palette/color_token.dart';
import '../palette/derive.dart' show retoneUnknown;
import '../palette/palette_token.dart';
import '../palette/resolved_palette.dart';
import 'color_scheme.dart';
import 'legacy_roles.dart';

/// A [ThemeExtension] of your own that [recolor] should carry into the other
/// brightness.
///
/// ```dart
/// class BrandColors extends ThemeExtension<BrandColors> implements Recolorable {
///   // ...
///   @override
///   BrandColors recolor(ColorMapper mapper) => BrandColors(
///     banner: mapper.map(banner, TokenRole.surface),
///     badge: mapper.map(badge, TokenRole.accent),
///   );
/// }
/// ```
///
/// Extensions that don't implement it are kept as they are. You can also pass
/// ready-made dark versions to `ThemeFlow(darkExtensions: ...)`.
abstract interface class Recolorable {
  /// Returns this extension with every color passed through [mapper].
  ThemeExtension<dynamic> recolor(ColorMapper mapper);
}

/// Carries every color in [theme] from palette [from] to palette [to], and
/// keeps everything else: fonts, shapes, paddings, elevations, densities.
///
/// * A color that matches a token in [from] becomes the same token in [to].
///   The match is alpha-aware, so `primary` at 12% stays at 12%.
/// * When the brightness changes, a color that matches no token is re-toned
///   by the role of the field it sits in: backgrounds turn into surfaces,
///   foregrounds into content, borders into outlines. When the brightness
///   stays the same, such colors are left alone.
/// * Foregrounds that sit on a known background in the same component are
///   checked against the recolored background and fixed if needed.
///
/// The result carries [to] as its palette extension, plus [extensions], which
/// replace any of the same type.
ThemeData recolor(
  ThemeData theme, {
  required ResolvedPalette from,
  required ResolvedPalette to,
  Iterable<ThemeExtension<dynamic>> extensions = const [],
}) {
  final mapper = ColorMapper(from, to);
  if (from == to) {
    return theme.copyWith(extensions: mapper._extensions(theme, extensions));
  }
  return mapper._theme(theme, extensions);
}

/// Where a color sits. It decides how a color that matches no token is
/// carried over, and which tokens are preferred when several match.
enum _Kind {
  surface,
  inverse,
  fill,
  content,
  onFill,
  outline,
  accent,
  container,
  overlay,
  shadow,
  scrim,
}

const Map<_Kind, Set<TokenRole>> _families = {
  _Kind.surface: {TokenRole.surface, TokenRole.container},
  _Kind.inverse: {TokenRole.surface},
  _Kind.fill: {TokenRole.surface, TokenRole.container},
  _Kind.content: {TokenRole.content, TokenRole.onColor},
  _Kind.onFill: {TokenRole.onColor, TokenRole.content},
  _Kind.outline: {TokenRole.outline},
  _Kind.accent: {TokenRole.accent},
  _Kind.container: {TokenRole.container, TokenRole.surface},
  _Kind.overlay: {TokenRole.content},
  _Kind.shadow: {TokenRole.fixed},
  _Kind.scrim: {TokenRole.fixed},
};

/// Maps colors from one palette to another, the way [recolor] does.
///
/// It's handed to [Recolorable.recolor] so your own theme extensions can be
/// carried over with the same rules.
class ColorMapper {
  /// Creates a mapper from palette [from] to palette [to].
  ColorMapper(this.from, this.to)
    : flipsBrightness = from.brightness != to.brightness,
      _fromScheme = schemeFromPalette(from),
      _toScheme = schemeFromPalette(to) {
    for (final token in PaletteToken.values) {
      _byRgb.putIfAbsent(_rgb(from[token]), () => []).add(token);
    }
  }

  /// The palette colors are mapped from.
  final ResolvedPalette from;

  /// The palette colors are mapped to.
  final ResolvedPalette to;

  /// Whether [from] and [to] have different brightnesses.
  final bool flipsBrightness;

  final ColorScheme _fromScheme;
  final ColorScheme _toScheme;
  final Map<int, List<PaletteToken>> _byRgb = {};
  final Map<(int, _Kind, PaletteToken?), Color> _cache = {};

  /// Maps [color], which is drawn in a place with the given [role].
  Color map(Color color, TokenRole role) => switch (role) {
    TokenRole.fixed => color,
    TokenRole.surface => _map(color, _Kind.surface),
    TokenRole.content => _map(color, _Kind.content),
    TokenRole.outline => _map(color, _Kind.outline),
    TokenRole.accent => _map(color, _Kind.accent),
    TokenRole.container => _map(color, _Kind.container),
    TokenRole.onColor => _map(color, _Kind.onFill),
  };

  static int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;
  static int _alpha8(Color c) => (c.a * 255).round();

  Color _map(Color color, _Kind kind, [PaletteToken? natural]) {
    if (color is CupertinoDynamicColor) return color; // resolves itself
    if (color is ColorToken) return to.resolve(color);
    if (color is WidgetStateColor) {
      return WidgetStateColor.resolveWith(
        (states) => _map(color.resolve(states), kind, natural),
      );
    }
    if (color.a == 0) return color;
    return _cache.putIfAbsent((
      color.toARGB32(),
      kind,
      natural,
    ), () => _compute(color, kind, natural));
  }

  Color? _c(Color? color, _Kind kind, [PaletteToken? natural]) =>
      color == null ? null : _map(color, kind, natural);

  Color _compute(Color color, _Kind kind, PaletteToken? natural) {
    final match = _match(color, kind, natural);
    if (match != null) {
      final source = from[match];
      final target = to[match];
      if (_alpha8(color) == _alpha8(source)) return target;
      final alpha = source.a == 0 ? color.a : color.a * target.a / source.a;
      return target.withValues(alpha: alpha.clamp(0.0, 1.0));
    }
    if (!flipsBrightness) return color;
    return _retone(color, kind);
  }

  PaletteToken? _match(Color color, _Kind kind, PaletteToken? natural) {
    final candidates = _byRgb[_rgb(color)];
    if (candidates == null) return null;
    final alpha = _alpha8(color);
    final ok = [
      for (final t in candidates)
        if (_alpha8(from[t]) == alpha || from[t].a == 1) t,
    ];
    if (ok.isEmpty) return null;
    if (natural != null && ok.contains(natural)) return natural;
    final family = _families[kind]!;
    for (final t in ok) {
      if (family.contains(t.role)) return t;
    }
    return ok.first;
  }

  Color _retone(Color color, _Kind kind) {
    Color via(TokenRole role, {bool contrast = true}) => retoneUnknown(
      color,
      role,
      to: to.brightness,
      style: to.style,
      toBackground: to.background,
      fromBackground: from.background,
      enforceContrast: contrast,
    );

    switch (kind) {
      case _Kind.shadow:
      case _Kind.scrim:
        return color;
      case _Kind.overlay:
        return retoneUnknown(
          color.withValues(alpha: 1),
          TokenRole.content,
          to: to.brightness,
          style: to.style,
          toBackground: to.background,
          fromBackground: from.background,
          enforceContrast: false,
        ).withValues(alpha: color.a);
      case _Kind.inverse:
        return via(TokenRole.content, contrast: false);
      case _Kind.fill:
        return Oklch.fromColor(color).c >= 0.04
            ? via(TokenRole.accent)
            : _retoneFill(color);
      case _Kind.surface:
        return via(TokenRole.surface);
      case _Kind.content:
      case _Kind.onFill:
        return via(TokenRole.content);
      case _Kind.outline:
        return via(TokenRole.outline);
      case _Kind.accent:
        return via(TokenRole.accent);
      case _Kind.container:
        return via(TokenRole.container);
    }
  }

  // Small greyish fills (a white button, a grey chip) sit a step above the
  // background in dark mode so they stay visible.
  Color _retoneFill(Color color) {
    final src = Oklch.fromColor(color);
    final toBgL = Oklch.fromColor(to.background).l;
    final fromBgL = Oklch.fromColor(from.background).l;
    final distance = (src.l - fromBgL).abs();
    final double l;
    if (to.brightness == Brightness.dark) {
      l = src.l >= 0.5
          ? math.min(toBgL + 0.07 + 0.6 * distance, 0.45)
          : src.l.clamp(0.15, 0.45);
    } else {
      l = src.l <= 0.5
          ? math.max(toBgL - 0.05 - 0.6 * distance, 0.80)
          : src.l.clamp(0.80, 1.0);
    }
    return Oklch(l, math.min(src.c, 0.03), src.h, src.alpha).toColor();
  }

  // A foreground that sat on [bg]: keeps at least the contrast it had, up to
  // 4.5:1, against the recolored background.
  Color _pair(Color fg, Color bg, Color mappedFg, Color mappedBg) {
    if (!flipsBrightness || mappedBg.a == 0) return mappedFg;
    final need = math.min(contrastRatio(fg, bg), 4.5);
    if (contrastRatio(mappedFg, mappedBg) + 0.01 >= need) return mappedFg;
    final fixed = ensureContrast(mappedFg, mappedBg, need);
    if (contrastRatio(fixed, mappedBg) + 0.01 >= need) return fixed;
    return bestOn(mappedBg).withValues(alpha: mappedFg.a);
  }

  Color? _on(Color? fg, Color? bg, Color? mappedBg, [PaletteToken? natural]) {
    if (fg == null) return null;
    final mapped = _map(fg, _Kind.onFill, natural);
    if (bg == null ||
        mappedBg == null ||
        fg is WidgetStateColor ||
        bg is WidgetStateColor ||
        fg is CupertinoDynamicColor) {
      return mapped;
    }
    return _pair(fg, bg, mapped, mappedBg);
  }

  // ---------------------------------------------------------------- values

  TextStyle? _text(
    TextStyle? style,
    _Kind kind, [
    PaletteToken? natural,
    Color? on,
    Color? mappedOn,
  ]) {
    if (style == null) return null;
    if (style is WidgetStateTextStyle) {
      return WidgetStateTextStyle.resolveWith(
        (states) => _text(style.resolve(states), kind, natural, on, mappedOn)!,
      );
    }
    final color = style.color;
    Color? mapped;
    if (color != null && style.foreground == null) {
      mapped = on != null && mappedOn != null
          ? _on(color, on, mappedOn, natural)
          : _map(color, kind, natural);
    }
    return style.copyWith(
      color: mapped,
      backgroundColor: style.background == null
          ? _c(style.backgroundColor, _Kind.fill)
          : null,
      decorationColor: _c(style.decorationColor, kind, natural),
      shadows: style.shadows == null
          ? null
          : [for (final s in style.shadows!) _textShadow(s)],
    );
  }

  Shadow _textShadow(Shadow s) => s is BoxShadow
      ? _boxShadow(s)
      : Shadow(
          color: _map(s.color, _Kind.shadow),
          offset: s.offset,
          blurRadius: s.blurRadius,
        );

  BoxShadow _boxShadow(BoxShadow s) =>
      s.copyWith(color: _map(s.color, _Kind.shadow));

  TextTheme _textTheme(TextTheme t, _Kind kind, PaletteToken natural) {
    TextStyle? m(TextStyle? s) => _text(s, kind, natural);
    return t.copyWith(
      displayLarge: m(t.displayLarge),
      displayMedium: m(t.displayMedium),
      displaySmall: m(t.displaySmall),
      headlineLarge: m(t.headlineLarge),
      headlineMedium: m(t.headlineMedium),
      headlineSmall: m(t.headlineSmall),
      titleLarge: m(t.titleLarge),
      titleMedium: m(t.titleMedium),
      titleSmall: m(t.titleSmall),
      bodyLarge: m(t.bodyLarge),
      bodyMedium: m(t.bodyMedium),
      bodySmall: m(t.bodySmall),
      labelLarge: m(t.labelLarge),
      labelMedium: m(t.labelMedium),
      labelSmall: m(t.labelSmall),
    );
  }

  IconThemeData? _icon(
    IconThemeData? icon,
    _Kind kind, [
    PaletteToken? natural,
    Color? on,
    Color? mappedOn,
  ]) {
    if (icon == null) return null;
    final color = icon.color;
    return icon.copyWith(
      color: color == null
          ? null
          : (on != null && mappedOn != null
                ? _on(color, on, mappedOn, natural)
                : _map(color, kind, natural)),
      shadows: icon.shadows == null
          ? null
          : [for (final s in icon.shadows!) _textShadow(s)],
    );
  }

  BorderSide? _side(
    BorderSide? side, [
    _Kind kind = _Kind.outline,
    PaletteToken? natural,
  ]) {
    if (side == null) return null;
    if (side is WidgetStateBorderSide) {
      return WidgetStateBorderSide.resolveWith(
        (states) => _side(side.resolve(states), kind, natural),
      );
    }
    if (side.style == BorderStyle.none) return side;
    return side.copyWith(color: _map(side.color, kind, natural));
  }

  T? _shape<T extends ShapeBorder>(
    T? shape, [
    _Kind kind = _Kind.outline,
    PaletteToken? natural,
  ]) {
    if (shape == null) return null;
    final ShapeBorder result;
    if (shape is WidgetStateOutlinedBorder) {
      result = WidgetStateOutlinedBorder.resolveWith(
        (states) =>
            _shape<OutlinedBorder>(shape.resolve(states), kind, natural),
      );
    } else if (shape is WidgetStateInputBorder) {
      final input = shape as WidgetStateInputBorder;
      result = WidgetStateInputBorder.resolveWith(
        (states) => _shape<InputBorder>(input.resolve(states), kind, natural)!,
      );
    } else if (shape is InputBorder) {
      result = shape.copyWith(
        borderSide: _side(shape.borderSide, kind, natural),
      );
    } else if (shape is OutlinedBorder) {
      result = shape.copyWith(side: _side(shape.side, kind, natural));
    } else if (shape is Border) {
      result = Border(
        top: _side(shape.top, kind, natural)!,
        right: _side(shape.right, kind, natural)!,
        bottom: _side(shape.bottom, kind, natural)!,
        left: _side(shape.left, kind, natural)!,
      );
    } else if (shape is BorderDirectional) {
      result = BorderDirectional(
        top: _side(shape.top, kind, natural)!,
        start: _side(shape.start, kind, natural)!,
        end: _side(shape.end, kind, natural)!,
        bottom: _side(shape.bottom, kind, natural)!,
      );
    } else {
      result = shape;
    }
    return result as T;
  }

  Gradient? _gradient(Gradient? g) {
    if (g == null) return null;
    final colors = [for (final c in g.colors) _map(c, _Kind.fill)];
    return switch (g) {
      LinearGradient() => LinearGradient(
        begin: g.begin,
        end: g.end,
        colors: colors,
        stops: g.stops,
        tileMode: g.tileMode,
        transform: g.transform,
      ),
      RadialGradient() => RadialGradient(
        center: g.center,
        radius: g.radius,
        colors: colors,
        stops: g.stops,
        tileMode: g.tileMode,
        focal: g.focal,
        focalRadius: g.focalRadius,
        transform: g.transform,
      ),
      SweepGradient() => SweepGradient(
        center: g.center,
        startAngle: g.startAngle,
        endAngle: g.endAngle,
        colors: colors,
        stops: g.stops,
        tileMode: g.tileMode,
        transform: g.transform,
      ),
      _ => g,
    };
  }

  Decoration? _decoration(Decoration? d, _Kind kind, [PaletteToken? natural]) {
    return switch (d) {
      null => null,
      BoxDecoration() => d.copyWith(
        color: _c(d.color, kind, natural),
        border: _shape(d.border),
        boxShadow: d.boxShadow == null
            ? null
            : [for (final s in d.boxShadow!) _boxShadow(s)],
        gradient: _gradient(d.gradient),
      ),
      ShapeDecoration() => ShapeDecoration(
        color: _c(d.color, kind, natural),
        image: d.image,
        gradient: _gradient(d.gradient),
        shadows: d.shadows == null
            ? null
            : [for (final s in d.shadows!) _boxShadow(s)],
        shape: _shape(d.shape)!,
      ),
      UnderlineTabIndicator() => UnderlineTabIndicator(
        borderRadius: d.borderRadius,
        borderSide: _side(d.borderSide, _Kind.accent, PaletteToken.primary)!,
        insets: d.insets,
      ),
      _ => d,
    };
  }

  SystemUiOverlayStyle? _overlayStyle(SystemUiOverlayStyle? s) {
    if (s == null) return null;
    Brightness? flip(Brightness? b) => b == null || !flipsBrightness
        ? b
        : (b == Brightness.dark ? Brightness.light : Brightness.dark);
    return s.copyWith(
      statusBarColor: _c(
        s.statusBarColor,
        _Kind.surface,
        PaletteToken.background,
      ),
      statusBarBrightness: flip(s.statusBarBrightness),
      statusBarIconBrightness: flip(s.statusBarIconBrightness),
      systemNavigationBarColor: _c(
        s.systemNavigationBarColor,
        _Kind.surface,
        PaletteToken.background,
      ),
      systemNavigationBarDividerColor: _c(
        s.systemNavigationBarDividerColor,
        _Kind.outline,
        PaletteToken.divider,
      ),
      systemNavigationBarIconBrightness: flip(
        s.systemNavigationBarIconBrightness,
      ),
    );
  }

  WidgetStateProperty<Color?>? _wsp(
    WidgetStateProperty<Color?>? p,
    _Kind kind, [
    PaletteToken? natural,
  ]) {
    if (p == null) return null;
    if (p is WidgetStatePropertyAll<Color?>) {
      return WidgetStatePropertyAll<Color?>(_c(p.value, kind, natural));
    }
    return WidgetStateProperty.resolveWith(
      (states) => _c(p.resolve(states), kind, natural),
    );
  }

  // A foreground property drawn on a background property: paired per state.
  WidgetStateProperty<Color?>? _wspOn(
    WidgetStateProperty<Color?>? fg,
    WidgetStateProperty<Color?>? bg,
    _Kind bgKind, [
    PaletteToken? natural,
  ]) {
    if (fg == null) return null;
    if (bg == null || !flipsBrightness) return _wsp(fg, _Kind.onFill, natural);
    return WidgetStateProperty.resolveWith((states) {
      final f = fg.resolve(states);
      if (f == null) return null;
      final mapped = _map(f, _Kind.onFill, natural);
      final b = bg.resolve(states);
      if (b == null || b.a == 0) return mapped;
      return _pair(f, b, mapped, _map(b, bgKind));
    });
  }

  WidgetStateProperty<T?>? _wspOf<T>(
    WidgetStateProperty<T?>? p,
    T? Function(T?) f,
  ) {
    if (p == null) return null;
    if (p is WidgetStatePropertyAll<T?>) {
      return WidgetStatePropertyAll<T?>(f(p.value));
    }
    return WidgetStateProperty.resolveWith((states) => f(p.resolve(states)));
  }

  ButtonStyle? _button(ButtonStyle? s) {
    if (s == null) return null;
    return s.copyWith(
      textStyle: _wspOf(s.textStyle, (t) => _text(t, _Kind.content)),
      backgroundColor: _wsp(s.backgroundColor, _Kind.fill),
      foregroundColor: _wspOn(s.foregroundColor, s.backgroundColor, _Kind.fill),
      overlayColor: _wsp(s.overlayColor, _Kind.overlay),
      shadowColor: _wsp(s.shadowColor, _Kind.shadow, PaletteToken.shadow),
      surfaceTintColor: _wsp(
        s.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      iconColor: _wspOn(s.iconColor, s.backgroundColor, _Kind.fill),
      side: _wspOf(s.side, (b) => _side(b)),
      shape: _wspOf(s.shape, (b) => _shape(b)),
    );
  }

  MenuStyle? _menuStyle(MenuStyle? s) {
    if (s == null) return null;
    return s.copyWith(
      backgroundColor: _wsp(
        s.backgroundColor,
        _Kind.surface,
        PaletteToken.surfaceElevated,
      ),
      shadowColor: _wsp(s.shadowColor, _Kind.shadow, PaletteToken.shadow),
      surfaceTintColor: _wsp(
        s.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      side: _wspOf(s.side, (b) => _side(b)),
      shape: _wspOf(s.shape, (b) => _shape(b)),
    );
  }

  InputDecorationThemeData? _input(InputDecorationThemeData? t) {
    if (t == null) return null;
    return t.copyWith(
      labelStyle: _text(
        t.labelStyle,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      floatingLabelStyle: _text(t.floatingLabelStyle, _Kind.content),
      helperStyle: _text(
        t.helperStyle,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      hintStyle: _text(t.hintStyle, _Kind.content, PaletteToken.textTertiary),
      errorStyle: _text(t.errorStyle, _Kind.accent, PaletteToken.error),
      iconColor: _c(t.iconColor, _Kind.content, PaletteToken.textSecondary),
      prefixStyle: _text(t.prefixStyle, _Kind.content),
      prefixIconColor: _c(
        t.prefixIconColor,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      suffixStyle: _text(t.suffixStyle, _Kind.content),
      suffixIconColor: _c(
        t.suffixIconColor,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      counterStyle: _text(
        t.counterStyle,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      fillColor: _c(t.fillColor, _Kind.fill, PaletteToken.fill),
      activeIndicatorBorder: _side(t.activeIndicatorBorder),
      outlineBorder: _side(t.outlineBorder, _Kind.outline, PaletteToken.border),
      focusColor: _c(t.focusColor, _Kind.overlay),
      hoverColor: _c(t.hoverColor, _Kind.overlay),
      errorBorder: _shape(t.errorBorder, _Kind.accent, PaletteToken.error),
      focusedBorder: _shape(
        t.focusedBorder,
        _Kind.accent,
        PaletteToken.primary,
      ),
      focusedErrorBorder: _shape(
        t.focusedErrorBorder,
        _Kind.accent,
        PaletteToken.error,
      ),
      disabledBorder: _shape(t.disabledBorder),
      enabledBorder: _shape(
        t.enabledBorder,
        _Kind.outline,
        PaletteToken.border,
      ),
      border: _shape(t.border, _Kind.outline, PaletteToken.border),
    );
  }

  InputDecorationTheme? _inputTheme(InputDecorationThemeData? t) =>
      t == null ? null : InputDecorationTheme(data: _input(t));

  ColorScheme _scheme(ColorScheme s) {
    final f = _fromScheme;
    final t = _toScheme;
    Color role(Color base, Color fromRole, Color toRole, _Kind kind) =>
        base == fromRole ? toRole : _map(base, kind);
    Color fixedRole(Color base, Color fromRole, Color toRole) =>
        base == fromRole ? toRole : base;
    final scheme = s.copyWith(
      brightness: to.brightness,
      primary: role(s.primary, f.primary, t.primary, _Kind.accent),
      onPrimary: role(s.onPrimary, f.onPrimary, t.onPrimary, _Kind.onFill),
      primaryContainer: role(
        s.primaryContainer,
        f.primaryContainer,
        t.primaryContainer,
        _Kind.container,
      ),
      onPrimaryContainer: role(
        s.onPrimaryContainer,
        f.onPrimaryContainer,
        t.onPrimaryContainer,
        _Kind.onFill,
      ),
      primaryFixed: fixedRole(s.primaryFixed, f.primaryFixed, t.primaryFixed),
      primaryFixedDim: fixedRole(
        s.primaryFixedDim,
        f.primaryFixedDim,
        t.primaryFixedDim,
      ),
      onPrimaryFixed: fixedRole(
        s.onPrimaryFixed,
        f.onPrimaryFixed,
        t.onPrimaryFixed,
      ),
      onPrimaryFixedVariant: fixedRole(
        s.onPrimaryFixedVariant,
        f.onPrimaryFixedVariant,
        t.onPrimaryFixedVariant,
      ),
      secondary: role(s.secondary, f.secondary, t.secondary, _Kind.accent),
      onSecondary: role(
        s.onSecondary,
        f.onSecondary,
        t.onSecondary,
        _Kind.onFill,
      ),
      secondaryContainer: role(
        s.secondaryContainer,
        f.secondaryContainer,
        t.secondaryContainer,
        _Kind.container,
      ),
      onSecondaryContainer: role(
        s.onSecondaryContainer,
        f.onSecondaryContainer,
        t.onSecondaryContainer,
        _Kind.onFill,
      ),
      secondaryFixed: fixedRole(
        s.secondaryFixed,
        f.secondaryFixed,
        t.secondaryFixed,
      ),
      secondaryFixedDim: fixedRole(
        s.secondaryFixedDim,
        f.secondaryFixedDim,
        t.secondaryFixedDim,
      ),
      onSecondaryFixed: fixedRole(
        s.onSecondaryFixed,
        f.onSecondaryFixed,
        t.onSecondaryFixed,
      ),
      onSecondaryFixedVariant: fixedRole(
        s.onSecondaryFixedVariant,
        f.onSecondaryFixedVariant,
        t.onSecondaryFixedVariant,
      ),
      tertiary: role(s.tertiary, f.tertiary, t.tertiary, _Kind.accent),
      onTertiary: role(s.onTertiary, f.onTertiary, t.onTertiary, _Kind.onFill),
      tertiaryContainer: role(
        s.tertiaryContainer,
        f.tertiaryContainer,
        t.tertiaryContainer,
        _Kind.container,
      ),
      onTertiaryContainer: role(
        s.onTertiaryContainer,
        f.onTertiaryContainer,
        t.onTertiaryContainer,
        _Kind.onFill,
      ),
      tertiaryFixed: fixedRole(
        s.tertiaryFixed,
        f.tertiaryFixed,
        t.tertiaryFixed,
      ),
      tertiaryFixedDim: fixedRole(
        s.tertiaryFixedDim,
        f.tertiaryFixedDim,
        t.tertiaryFixedDim,
      ),
      onTertiaryFixed: fixedRole(
        s.onTertiaryFixed,
        f.onTertiaryFixed,
        t.onTertiaryFixed,
      ),
      onTertiaryFixedVariant: fixedRole(
        s.onTertiaryFixedVariant,
        f.onTertiaryFixedVariant,
        t.onTertiaryFixedVariant,
      ),
      error: role(s.error, f.error, t.error, _Kind.accent),
      onError: role(s.onError, f.onError, t.onError, _Kind.onFill),
      errorContainer: role(
        s.errorContainer,
        f.errorContainer,
        t.errorContainer,
        _Kind.container,
      ),
      onErrorContainer: role(
        s.onErrorContainer,
        f.onErrorContainer,
        t.onErrorContainer,
        _Kind.onFill,
      ),
      surface: role(s.surface, f.surface, t.surface, _Kind.surface),
      onSurface: role(s.onSurface, f.onSurface, t.onSurface, _Kind.content),
      onSurfaceVariant: role(
        s.onSurfaceVariant,
        f.onSurfaceVariant,
        t.onSurfaceVariant,
        _Kind.content,
      ),
      surfaceDim: role(s.surfaceDim, f.surfaceDim, t.surfaceDim, _Kind.surface),
      surfaceBright: role(
        s.surfaceBright,
        f.surfaceBright,
        t.surfaceBright,
        _Kind.surface,
      ),
      surfaceContainerLowest: role(
        s.surfaceContainerLowest,
        f.surfaceContainerLowest,
        t.surfaceContainerLowest,
        _Kind.surface,
      ),
      surfaceContainerLow: role(
        s.surfaceContainerLow,
        f.surfaceContainerLow,
        t.surfaceContainerLow,
        _Kind.surface,
      ),
      surfaceContainer: role(
        s.surfaceContainer,
        f.surfaceContainer,
        t.surfaceContainer,
        _Kind.surface,
      ),
      surfaceContainerHigh: role(
        s.surfaceContainerHigh,
        f.surfaceContainerHigh,
        t.surfaceContainerHigh,
        _Kind.surface,
      ),
      surfaceContainerHighest: role(
        s.surfaceContainerHighest,
        f.surfaceContainerHighest,
        t.surfaceContainerHighest,
        _Kind.fill,
      ),
      outline: role(s.outline, f.outline, t.outline, _Kind.outline),
      outlineVariant: role(
        s.outlineVariant,
        f.outlineVariant,
        t.outlineVariant,
        _Kind.outline,
      ),
      shadow: role(s.shadow, f.shadow, t.shadow, _Kind.shadow),
      scrim: role(s.scrim, f.scrim, t.scrim, _Kind.scrim),
      inverseSurface: role(
        s.inverseSurface,
        f.inverseSurface,
        t.inverseSurface,
        _Kind.inverse,
      ),
      onInverseSurface: role(
        s.onInverseSurface,
        f.onInverseSurface,
        t.onInverseSurface,
        _Kind.onFill,
      ),
      inversePrimary: flipsBrightness
          ? t.inversePrimary
          : role(
              s.inversePrimary,
              f.inversePrimary,
              t.inversePrimary,
              _Kind.accent,
            ),
      surfaceTint: role(
        s.surfaceTint,
        f.surfaceTint,
        t.surfaceTint,
        _Kind.accent,
      ),
    );
    return carryLegacyRoles(
      scheme,
      source: s,
      from: f,
      to: t,
      map: (c, {required content}) =>
          _map(c, content ? _Kind.content : _Kind.surface),
    );
  }

  Iterable<ThemeExtension<dynamic>> _extensions(
    ThemeData theme,
    Iterable<ThemeExtension<dynamic>> replace,
  ) {
    // Same cast Flutter's own ThemeData uses: ThemeExtension is F-bounded.
    final out = <Object, ThemeExtension<ThemeExtension<dynamic>>>{};
    void put(ThemeExtension<dynamic> e) =>
        out[e.type] = e as ThemeExtension<ThemeExtension<dynamic>>;
    for (final e in theme.extensions.values) {
      if (e is ResolvedPalette) continue;
      put(e is Recolorable ? (e as Recolorable).recolor(this) : e);
    }
    replace.forEach(put);
    put(to);
    return out.values;
  }

  NoDefaultCupertinoThemeData? _cupertino(NoDefaultCupertinoThemeData? c) {
    if (c == null) return null;
    final text = c.textTheme;
    return c.copyWith(
      brightness: c.brightness == null ? null : to.brightness,
      primaryColor: _c(c.primaryColor, _Kind.accent, PaletteToken.primary),
      primaryContrastingColor: _c(
        c.primaryContrastingColor,
        _Kind.onFill,
        PaletteToken.onPrimary,
      ),
      textTheme: text?.copyWith(
        textStyle: _text(text.textStyle, _Kind.content, PaletteToken.text),
        actionTextStyle: _text(text.actionTextStyle, _Kind.accent),
        actionSmallTextStyle: _text(text.actionSmallTextStyle, _Kind.accent),
        tabLabelTextStyle: _text(text.tabLabelTextStyle, _Kind.content),
        navTitleTextStyle: _text(text.navTitleTextStyle, _Kind.content),
        navLargeTitleTextStyle: _text(
          text.navLargeTitleTextStyle,
          _Kind.content,
        ),
        navActionTextStyle: _text(text.navActionTextStyle, _Kind.accent),
        pickerTextStyle: _text(text.pickerTextStyle, _Kind.content),
        dateTimePickerTextStyle: _text(
          text.dateTimePickerTextStyle,
          _Kind.content,
        ),
      ),
      barBackgroundColor: _c(
        c.barBackgroundColor,
        _Kind.surface,
        PaletteToken.surface,
      ),
      scaffoldBackgroundColor: _c(
        c.scaffoldBackgroundColor,
        _Kind.surface,
        PaletteToken.background,
      ),
      selectionHandleColor: _c(
        c.selectionHandleColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
    );
  }

  // ------------------------------------------------------- component themes

  AppBarThemeData _appBar(AppBarThemeData t) {
    final bg = t.backgroundColor;
    final mappedBg = _c(bg, _Kind.surface, PaletteToken.background);
    return t.copyWith(
      backgroundColor: mappedBg,
      foregroundColor: _on(t.foregroundColor, bg, mappedBg, PaletteToken.text),
      shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
      surfaceTintColor: _c(
        t.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      shape: _shape(t.shape),
      iconTheme: _icon(
        t.iconTheme,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
      actionsIconTheme: _icon(
        t.actionsIconTheme,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
      toolbarTextStyle: _text(
        t.toolbarTextStyle,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
      titleTextStyle: _text(
        t.titleTextStyle,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
      systemOverlayStyle: _overlayStyle(t.systemOverlayStyle),
    );
  }

  BadgeThemeData _badge(BadgeThemeData t) {
    final bg = t.backgroundColor;
    final mappedBg = _c(bg, _Kind.fill, PaletteToken.error);
    return t.copyWith(
      backgroundColor: mappedBg,
      textColor: _on(t.textColor, bg, mappedBg, PaletteToken.onError),
      textStyle: _text(
        t.textStyle,
        _Kind.onFill,
        PaletteToken.onError,
        bg,
        mappedBg,
      ),
    );
  }

  MaterialBannerThemeData _banner(MaterialBannerThemeData t) {
    final bg = t.backgroundColor;
    final mappedBg = _c(bg, _Kind.surface, PaletteToken.surface);
    return t.copyWith(
      backgroundColor: mappedBg,
      surfaceTintColor: _c(
        t.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
      dividerColor: _c(t.dividerColor, _Kind.outline, PaletteToken.divider),
      contentTextStyle: _text(
        t.contentTextStyle,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
    );
  }

  BottomAppBarThemeData _bottomAppBar(BottomAppBarThemeData t) => t.copyWith(
    color: _c(t.color, _Kind.surface, PaletteToken.surface),
    surfaceTintColor: _c(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
  );

  BottomNavigationBarThemeData _bottomNav(BottomNavigationBarThemeData t) =>
      t.copyWith(
        backgroundColor: _c(
          t.backgroundColor,
          _Kind.surface,
          PaletteToken.surface,
        ),
        selectedIconTheme: _icon(
          t.selectedIconTheme,
          _Kind.accent,
          PaletteToken.primary,
        ),
        unselectedIconTheme: _icon(
          t.unselectedIconTheme,
          _Kind.content,
          PaletteToken.textSecondary,
        ),
        selectedItemColor: _c(
          t.selectedItemColor,
          _Kind.accent,
          PaletteToken.primary,
        ),
        unselectedItemColor: _c(
          t.unselectedItemColor,
          _Kind.content,
          PaletteToken.textSecondary,
        ),
        selectedLabelStyle: _text(
          t.selectedLabelStyle,
          _Kind.accent,
          PaletteToken.primary,
        ),
        unselectedLabelStyle: _text(
          t.unselectedLabelStyle,
          _Kind.content,
          PaletteToken.textSecondary,
        ),
      );

  BottomSheetThemeData _bottomSheet(BottomSheetThemeData t) => t.copyWith(
    backgroundColor: _c(t.backgroundColor, _Kind.surface, PaletteToken.surface),
    surfaceTintColor: _c(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    modalBackgroundColor: _c(
      t.modalBackgroundColor,
      _Kind.surface,
      PaletteToken.surface,
    ),
    modalBarrierColor: _c(t.modalBarrierColor, _Kind.scrim, PaletteToken.scrim),
    shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
    shape: _shape(t.shape),
    dragHandleColor: _c(t.dragHandleColor, _Kind.outline, PaletteToken.border),
  );

  // The legacy theme keeps its colors private. ThemeData fills them in from
  // its own fields, so those are carried over the same way.
  ButtonThemeData _legacyButton(ThemeData theme) {
    final t = theme.buttonTheme;
    final scheme = t.colorScheme;
    return t.copyWith(
      shape: _shape(t.shape),
      disabledColor: _map(
        theme.disabledColor,
        _Kind.content,
        PaletteToken.textDisabled,
      ),
      focusColor: _map(theme.focusColor, _Kind.overlay),
      hoverColor: _map(theme.hoverColor, _Kind.overlay),
      highlightColor: _map(theme.highlightColor, _Kind.overlay),
      splashColor: _map(theme.splashColor, _Kind.overlay),
      colorScheme: scheme == null ? null : _scheme(scheme),
    );
  }

  CardThemeData _card(CardThemeData t) => t.copyWith(
    color: _c(t.color, _Kind.surface, PaletteToken.surface),
    shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
    surfaceTintColor: _c(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    shape: _shape(t.shape),
  );

  CarouselViewThemeData _carousel(CarouselViewThemeData t) => t.copyWith(
    backgroundColor: _c(t.backgroundColor, _Kind.surface, PaletteToken.surface),
    shape: _shape(t.shape),
    overlayColor: _wsp(t.overlayColor, _Kind.overlay),
  );

  CheckboxThemeData _checkbox(CheckboxThemeData t) => t.copyWith(
    fillColor: _wsp(t.fillColor, _Kind.fill, PaletteToken.primary),
    checkColor: _wspOn(
      t.checkColor,
      t.fillColor,
      _Kind.fill,
      PaletteToken.onPrimary,
    ),
    overlayColor: _wsp(t.overlayColor, _Kind.overlay),
    shape: _shape(t.shape),
    side: _side(t.side, _Kind.outline, PaletteToken.border),
  );

  ChipThemeData _chip(ChipThemeData t) {
    final bg = t.backgroundColor;
    final mappedBg = _c(bg, _Kind.fill);
    return t.copyWith(
      color: _wsp(t.color, _Kind.fill),
      backgroundColor: mappedBg,
      deleteIconColor: _on(
        t.deleteIconColor,
        bg,
        mappedBg,
        PaletteToken.textSecondary,
      ),
      disabledColor: _c(t.disabledColor, _Kind.fill),
      selectedColor: _c(
        t.selectedColor,
        _Kind.fill,
        PaletteToken.secondaryContainer,
      ),
      secondarySelectedColor: _c(t.secondarySelectedColor, _Kind.fill),
      shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
      surfaceTintColor: _c(
        t.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      selectedShadowColor: _c(
        t.selectedShadowColor,
        _Kind.shadow,
        PaletteToken.shadow,
      ),
      checkmarkColor: _c(t.checkmarkColor, _Kind.onFill),
      side: _side(t.side, _Kind.outline, PaletteToken.border),
      shape: _shape(t.shape),
      labelStyle: _text(
        t.labelStyle,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
      secondaryLabelStyle: _text(t.secondaryLabelStyle, _Kind.content),
      iconTheme: _icon(
        t.iconTheme,
        _Kind.content,
        PaletteToken.textSecondary,
        bg,
        mappedBg,
      ),
    );
  }

  DataTableThemeData _dataTable(DataTableThemeData t) => t.copyWith(
    decoration: _decoration(t.decoration, _Kind.surface, PaletteToken.surface),
    dataRowColor: _wsp(t.dataRowColor, _Kind.surface),
    dataTextStyle: _text(t.dataTextStyle, _Kind.content, PaletteToken.text),
    headingRowColor: _wsp(t.headingRowColor, _Kind.surface),
    headingTextStyle: _text(
      t.headingTextStyle,
      _Kind.content,
      PaletteToken.text,
    ),
  );

  DatePickerThemeData _datePicker(DatePickerThemeData t) {
    final header = t.headerBackgroundColor;
    final mappedHeader = _c(header, _Kind.fill);
    final rangeHeader = t.rangePickerHeaderBackgroundColor;
    final mappedRangeHeader = _c(rangeHeader, _Kind.fill);
    return t.copyWith(
      backgroundColor: _c(
        t.backgroundColor,
        _Kind.surface,
        PaletteToken.surfaceElevated,
      ),
      shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
      surfaceTintColor: _c(
        t.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      shape: _shape(t.shape),
      headerBackgroundColor: mappedHeader,
      headerForegroundColor: _on(t.headerForegroundColor, header, mappedHeader),
      headerHeadlineStyle: _text(
        t.headerHeadlineStyle,
        _Kind.content,
        null,
        header,
        mappedHeader,
      ),
      headerHelpStyle: _text(
        t.headerHelpStyle,
        _Kind.content,
        null,
        header,
        mappedHeader,
      ),
      weekdayStyle: _text(t.weekdayStyle, _Kind.content),
      dayStyle: _text(t.dayStyle, _Kind.content),
      dayForegroundColor: _wspOn(
        t.dayForegroundColor,
        t.dayBackgroundColor,
        _Kind.fill,
      ),
      dayBackgroundColor: _wsp(t.dayBackgroundColor, _Kind.fill),
      dayOverlayColor: _wsp(t.dayOverlayColor, _Kind.overlay),
      dayShape: _wspOf(t.dayShape, (s) => _shape(s)),
      todayForegroundColor: _wspOn(
        t.todayForegroundColor,
        t.todayBackgroundColor,
        _Kind.fill,
      ),
      todayBackgroundColor: _wsp(t.todayBackgroundColor, _Kind.fill),
      todayBorder: _side(t.todayBorder, _Kind.accent, PaletteToken.primary),
      yearStyle: _text(t.yearStyle, _Kind.content),
      yearForegroundColor: _wspOn(
        t.yearForegroundColor,
        t.yearBackgroundColor,
        _Kind.fill,
      ),
      yearBackgroundColor: _wsp(t.yearBackgroundColor, _Kind.fill),
      yearOverlayColor: _wsp(t.yearOverlayColor, _Kind.overlay),
      yearShape: _wspOf(t.yearShape, (s) => _shape(s)),
      rangePickerBackgroundColor: _c(
        t.rangePickerBackgroundColor,
        _Kind.surface,
        PaletteToken.surfaceElevated,
      ),
      rangePickerShadowColor: _c(
        t.rangePickerShadowColor,
        _Kind.shadow,
        PaletteToken.shadow,
      ),
      rangePickerSurfaceTintColor: _c(
        t.rangePickerSurfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      rangePickerShape: _shape(t.rangePickerShape),
      rangePickerHeaderBackgroundColor: mappedRangeHeader,
      rangePickerHeaderForegroundColor: _on(
        t.rangePickerHeaderForegroundColor,
        rangeHeader,
        mappedRangeHeader,
      ),
      rangePickerHeaderHeadlineStyle: _text(
        t.rangePickerHeaderHeadlineStyle,
        _Kind.content,
        null,
        rangeHeader,
        mappedRangeHeader,
      ),
      rangePickerHeaderHelpStyle: _text(
        t.rangePickerHeaderHelpStyle,
        _Kind.content,
        null,
        rangeHeader,
        mappedRangeHeader,
      ),
      rangeSelectionBackgroundColor: _c(
        t.rangeSelectionBackgroundColor,
        _Kind.container,
        PaletteToken.secondaryContainer,
      ),
      rangeSelectionOverlayColor: _wsp(
        t.rangeSelectionOverlayColor,
        _Kind.overlay,
      ),
      dividerColor: _c(t.dividerColor, _Kind.outline, PaletteToken.divider),
      inputDecorationTheme: _inputTheme(t.inputDecorationTheme),
      cancelButtonStyle: _button(t.cancelButtonStyle),
      confirmButtonStyle: _button(t.confirmButtonStyle),
      toggleButtonTextStyle: _text(t.toggleButtonTextStyle, _Kind.content),
      subHeaderForegroundColor: _c(
        t.subHeaderForegroundColor,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
    );
  }

  DialogThemeData _dialog(DialogThemeData t) {
    final bg = t.backgroundColor;
    final mappedBg = _c(bg, _Kind.surface, PaletteToken.surfaceElevated);
    return t.copyWith(
      backgroundColor: mappedBg,
      shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
      surfaceTintColor: _c(
        t.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      shape: _shape(t.shape),
      iconColor: _on(t.iconColor, bg, mappedBg, PaletteToken.secondary),
      titleTextStyle: _text(
        t.titleTextStyle,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
      contentTextStyle: _text(
        t.contentTextStyle,
        _Kind.content,
        PaletteToken.textSecondary,
        bg,
        mappedBg,
      ),
      barrierColor: _c(t.barrierColor, _Kind.scrim, PaletteToken.scrim),
    );
  }

  DividerThemeData _divider(DividerThemeData t) =>
      t.copyWith(color: _c(t.color, _Kind.outline, PaletteToken.divider));

  DrawerThemeData _drawer(DrawerThemeData t) => t.copyWith(
    backgroundColor: _c(t.backgroundColor, _Kind.surface, PaletteToken.surface),
    scrimColor: _c(t.scrimColor, _Kind.scrim, PaletteToken.scrim),
    shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
    surfaceTintColor: _c(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    shape: _shape(t.shape),
    endShape: _shape(t.endShape),
  );

  DropdownMenuThemeData _dropdownMenu(DropdownMenuThemeData t) => t.copyWith(
    textStyle: _text(t.textStyle, _Kind.content, PaletteToken.text),
    inputDecorationTheme: _input(t.inputDecorationTheme),
    menuStyle: _menuStyle(t.menuStyle),
    disabledColor: _c(
      t.disabledColor,
      _Kind.content,
      PaletteToken.textDisabled,
    ),
  );

  ExpansionTileThemeData _expansionTile(ExpansionTileThemeData t) => t.copyWith(
    backgroundColor: _c(t.backgroundColor, _Kind.surface),
    collapsedBackgroundColor: _c(t.collapsedBackgroundColor, _Kind.surface),
    iconColor: _c(t.iconColor, _Kind.accent, PaletteToken.primary),
    collapsedIconColor: _c(
      t.collapsedIconColor,
      _Kind.content,
      PaletteToken.textSecondary,
    ),
    textColor: _c(t.textColor, _Kind.content, PaletteToken.text),
    collapsedTextColor: _c(
      t.collapsedTextColor,
      _Kind.content,
      PaletteToken.text,
    ),
    shape: _shape(t.shape),
    collapsedShape: _shape(t.collapsedShape),
  );

  FloatingActionButtonThemeData _fab(FloatingActionButtonThemeData t) {
    final bg = t.backgroundColor;
    final mappedBg = _c(bg, _Kind.fill, PaletteToken.primaryContainer);
    return t.copyWith(
      foregroundColor: _on(
        t.foregroundColor,
        bg,
        mappedBg,
        PaletteToken.onPrimaryContainer,
      ),
      backgroundColor: mappedBg,
      focusColor: _c(t.focusColor, _Kind.overlay),
      hoverColor: _c(t.hoverColor, _Kind.overlay),
      splashColor: _c(t.splashColor, _Kind.overlay),
      shape: _shape(t.shape),
      extendedTextStyle: _text(
        t.extendedTextStyle,
        _Kind.onFill,
        PaletteToken.onPrimaryContainer,
        bg,
        mappedBg,
      ),
    );
  }

  ListTileThemeData _listTile(ListTileThemeData t) => t.copyWith(
    shape: _shape(t.shape),
    selectedColor: _c(t.selectedColor, _Kind.accent, PaletteToken.primary),
    iconColor: _c(t.iconColor, _Kind.content, PaletteToken.textSecondary),
    textColor: _c(t.textColor, _Kind.content, PaletteToken.text),
    titleTextStyle: _text(t.titleTextStyle, _Kind.content, PaletteToken.text),
    subtitleTextStyle: _text(
      t.subtitleTextStyle,
      _Kind.content,
      PaletteToken.textSecondary,
    ),
    leadingAndTrailingTextStyle: _text(
      t.leadingAndTrailingTextStyle,
      _Kind.content,
      PaletteToken.textSecondary,
    ),
    tileColor: _c(t.tileColor, _Kind.surface, PaletteToken.surface),
    selectedTileColor: _c(t.selectedTileColor, _Kind.container),
  );

  NavigationBarThemeData _navigationBar(NavigationBarThemeData t) => t.copyWith(
    backgroundColor: _c(t.backgroundColor, _Kind.surface, PaletteToken.surface),
    shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
    surfaceTintColor: _c(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    indicatorColor: _c(
      t.indicatorColor,
      _Kind.fill,
      PaletteToken.secondaryContainer,
    ),
    indicatorShape: _shape(t.indicatorShape),
    labelTextStyle: _wspOf(t.labelTextStyle, (s) => _text(s, _Kind.content)),
    iconTheme: _wspOf(t.iconTheme, (i) => _icon(i, _Kind.content)),
    overlayColor: _wsp(t.overlayColor, _Kind.overlay),
  );

  NavigationDrawerThemeData _navigationDrawer(
    NavigationDrawerThemeData t,
  ) => t.copyWith(
    backgroundColor: _c(t.backgroundColor, _Kind.surface, PaletteToken.surface),
    shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
    surfaceTintColor: _c(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    indicatorColor: _c(
      t.indicatorColor,
      _Kind.fill,
      PaletteToken.secondaryContainer,
    ),
    indicatorShape: _shape(t.indicatorShape),
    labelTextStyle: _wspOf(t.labelTextStyle, (s) => _text(s, _Kind.content)),
    iconTheme: _wspOf(t.iconTheme, (i) => _icon(i, _Kind.content)),
  );

  NavigationRailThemeData _navigationRail(NavigationRailThemeData t) =>
      t.copyWith(
        backgroundColor: _c(
          t.backgroundColor,
          _Kind.surface,
          PaletteToken.surface,
        ),
        unselectedLabelTextStyle: _text(
          t.unselectedLabelTextStyle,
          _Kind.content,
          PaletteToken.textSecondary,
        ),
        selectedLabelTextStyle: _text(t.selectedLabelTextStyle, _Kind.content),
        unselectedIconTheme: _icon(
          t.unselectedIconTheme,
          _Kind.content,
          PaletteToken.textSecondary,
        ),
        selectedIconTheme: _icon(t.selectedIconTheme, _Kind.content),
        indicatorColor: _c(
          t.indicatorColor,
          _Kind.fill,
          PaletteToken.secondaryContainer,
        ),
        indicatorShape: _shape(t.indicatorShape),
      );

  PopupMenuThemeData _popupMenu(PopupMenuThemeData t) {
    final bg = t.color;
    final mappedBg = _c(bg, _Kind.surface, PaletteToken.surfaceElevated);
    return t.copyWith(
      color: mappedBg,
      shape: _shape(t.shape),
      shadowColor: _c(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
      surfaceTintColor: _c(
        t.surfaceTintColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      textStyle: _text(
        t.textStyle,
        _Kind.content,
        PaletteToken.text,
        bg,
        mappedBg,
      ),
      labelTextStyle: _wspOf(t.labelTextStyle, (s) => _text(s, _Kind.content)),
      iconColor: _on(t.iconColor, bg, mappedBg, PaletteToken.textSecondary),
    );
  }

  ProgressIndicatorThemeData _progress(ProgressIndicatorThemeData t) =>
      t.copyWith(
        color: _c(t.color, _Kind.accent, PaletteToken.primary),
        linearTrackColor: _c(
          t.linearTrackColor,
          _Kind.container,
          PaletteToken.secondaryContainer,
        ),
        circularTrackColor: _c(
          t.circularTrackColor,
          _Kind.container,
          PaletteToken.secondaryContainer,
        ),
        refreshBackgroundColor: _c(
          t.refreshBackgroundColor,
          _Kind.surface,
          PaletteToken.surfaceElevated,
        ),
        stopIndicatorColor: _c(
          t.stopIndicatorColor,
          _Kind.accent,
          PaletteToken.primary,
        ),
      );

  RadioThemeData _radio(RadioThemeData t) => t.copyWith(
    fillColor: _wsp(t.fillColor, _Kind.accent, PaletteToken.primary),
    overlayColor: _wsp(t.overlayColor, _Kind.overlay),
    backgroundColor: _wsp(t.backgroundColor, _Kind.surface),
    side: _side(t.side, _Kind.outline, PaletteToken.border),
  );

  ScrollbarThemeData _scrollbar(ScrollbarThemeData t) => t.copyWith(
    thumbColor: _wsp(t.thumbColor, _Kind.overlay),
    trackColor: _wsp(t.trackColor, _Kind.overlay),
    trackBorderColor: _wsp(t.trackBorderColor, _Kind.outline),
  );

  SearchBarThemeData _searchBar(SearchBarThemeData t) => t.copyWith(
    backgroundColor: _wsp(
      t.backgroundColor,
      _Kind.fill,
      PaletteToken.surfaceElevated,
    ),
    shadowColor: _wsp(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
    surfaceTintColor: _wsp(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    overlayColor: _wsp(t.overlayColor, _Kind.overlay),
    side: _wspOf(t.side, (b) => _side(b)),
    shape: _wspOf(t.shape, (s) => _shape(s)),
    textStyle: _wspOf(
      t.textStyle,
      (s) => _text(s, _Kind.content, PaletteToken.text),
    ),
    hintStyle: _wspOf(
      t.hintStyle,
      (s) => _text(s, _Kind.content, PaletteToken.textSecondary),
    ),
  );

  SearchViewThemeData _searchView(SearchViewThemeData t) => t.copyWith(
    backgroundColor: _c(
      t.backgroundColor,
      _Kind.surface,
      PaletteToken.surfaceElevated,
    ),
    surfaceTintColor: _c(
      t.surfaceTintColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
    side: _side(t.side),
    shape: _shape(t.shape),
    headerTextStyle: _text(t.headerTextStyle, _Kind.content, PaletteToken.text),
    headerHintStyle: _text(
      t.headerHintStyle,
      _Kind.content,
      PaletteToken.textSecondary,
    ),
    dividerColor: _c(t.dividerColor, _Kind.outline, PaletteToken.divider),
  );

  SliderThemeData _slider(SliderThemeData t) {
    final indicator = t.valueIndicatorColor;
    final mappedIndicator = _c(indicator, _Kind.fill, PaletteToken.primary);
    return t.copyWith(
      activeTrackColor: _c(
        t.activeTrackColor,
        _Kind.accent,
        PaletteToken.primary,
      ),
      inactiveTrackColor: _c(
        t.inactiveTrackColor,
        _Kind.container,
        PaletteToken.secondaryContainer,
      ),
      secondaryActiveTrackColor: _c(t.secondaryActiveTrackColor, _Kind.accent),
      disabledActiveTrackColor: _c(t.disabledActiveTrackColor, _Kind.content),
      disabledInactiveTrackColor: _c(
        t.disabledInactiveTrackColor,
        _Kind.content,
      ),
      disabledSecondaryActiveTrackColor: _c(
        t.disabledSecondaryActiveTrackColor,
        _Kind.content,
      ),
      activeTickMarkColor: _c(t.activeTickMarkColor, _Kind.onFill),
      inactiveTickMarkColor: _c(t.inactiveTickMarkColor, _Kind.accent),
      disabledActiveTickMarkColor: _c(
        t.disabledActiveTickMarkColor,
        _Kind.content,
      ),
      disabledInactiveTickMarkColor: _c(
        t.disabledInactiveTickMarkColor,
        _Kind.content,
      ),
      thumbColor: _c(t.thumbColor, _Kind.accent, PaletteToken.primary),
      overlappingShapeStrokeColor: _c(
        t.overlappingShapeStrokeColor,
        _Kind.surface,
      ),
      disabledThumbColor: _c(t.disabledThumbColor, _Kind.content),
      overlayColor: _c(t.overlayColor, _Kind.overlay),
      valueIndicatorColor: mappedIndicator,
      valueIndicatorStrokeColor: _c(t.valueIndicatorStrokeColor, _Kind.outline),
      valueIndicatorTextStyle: _text(
        t.valueIndicatorTextStyle,
        _Kind.onFill,
        PaletteToken.onPrimary,
        indicator,
        mappedIndicator,
      ),
    );
  }

  SnackBarThemeData _snackBar(SnackBarThemeData t) {
    final bg = t.backgroundColor;
    final mappedBg = _c(bg, _Kind.inverse, PaletteToken.inverseSurface);
    return t.copyWith(
      backgroundColor: mappedBg,
      actionTextColor: _on(t.actionTextColor, bg, mappedBg),
      disabledActionTextColor: _on(t.disabledActionTextColor, bg, mappedBg),
      contentTextStyle: _text(
        t.contentTextStyle,
        _Kind.onFill,
        PaletteToken.onInverseSurface,
        bg,
        mappedBg,
      ),
      shape: _shape(t.shape),
      closeIconColor: _on(
        t.closeIconColor,
        bg,
        mappedBg,
        PaletteToken.onInverseSurface,
      ),
      actionBackgroundColor: _c(t.actionBackgroundColor, _Kind.fill),
      disabledActionBackgroundColor: _c(
        t.disabledActionBackgroundColor,
        _Kind.fill,
      ),
    );
  }

  SwitchThemeData _switch(SwitchThemeData t) => t.copyWith(
    thumbColor: _wspOn(t.thumbColor, t.trackColor, _Kind.fill),
    trackColor: _wsp(t.trackColor, _Kind.fill, PaletteToken.primary),
    trackOutlineColor: _wsp(t.trackOutlineColor, _Kind.outline),
    overlayColor: _wsp(t.overlayColor, _Kind.overlay),
  );

  TabBarThemeData _tabBar(TabBarThemeData t) => t.copyWith(
    indicator: _decoration(t.indicator, _Kind.accent, PaletteToken.primary),
    indicatorColor: _c(t.indicatorColor, _Kind.accent, PaletteToken.primary),
    dividerColor: _c(t.dividerColor, _Kind.outline, PaletteToken.divider),
    labelColor: _c(t.labelColor, _Kind.accent, PaletteToken.primary),
    labelStyle: _text(t.labelStyle, _Kind.content),
    unselectedLabelColor: _c(
      t.unselectedLabelColor,
      _Kind.content,
      PaletteToken.textSecondary,
    ),
    unselectedLabelStyle: _text(t.unselectedLabelStyle, _Kind.content),
    overlayColor: _wsp(t.overlayColor, _Kind.overlay),
  );

  TextSelectionThemeData _textSelection(TextSelectionThemeData t) => t.copyWith(
    cursorColor: _c(t.cursorColor, _Kind.accent, PaletteToken.primary),
    selectionColor: _c(t.selectionColor, _Kind.accent, PaletteToken.selection),
    selectionHandleColor: _c(
      t.selectionHandleColor,
      _Kind.accent,
      PaletteToken.primary,
    ),
  );

  TimePickerThemeData _timePicker(TimePickerThemeData t) {
    final period = t.dayPeriodColor;
    final mappedPeriod = _c(period, _Kind.fill);
    final hourMinute = t.hourMinuteColor;
    final mappedHourMinute = _c(hourMinute, _Kind.fill);
    return t.copyWith(
      backgroundColor: _c(
        t.backgroundColor,
        _Kind.surface,
        PaletteToken.surfaceElevated,
      ),
      cancelButtonStyle: _button(t.cancelButtonStyle),
      confirmButtonStyle: _button(t.confirmButtonStyle),
      dayPeriodBorderSide: _side(t.dayPeriodBorderSide),
      dayPeriodColor: mappedPeriod,
      dayPeriodShape: _shape(t.dayPeriodShape),
      dayPeriodTextColor: _on(t.dayPeriodTextColor, period, mappedPeriod),
      dayPeriodTextStyle: _text(t.dayPeriodTextStyle, _Kind.content),
      dialBackgroundColor: _c(
        t.dialBackgroundColor,
        _Kind.fill,
        PaletteToken.fill,
      ),
      dialHandColor: _c(t.dialHandColor, _Kind.accent, PaletteToken.primary),
      dialTextColor: _c(t.dialTextColor, _Kind.content, PaletteToken.text),
      dialTextStyle: _text(t.dialTextStyle, _Kind.content),
      entryModeIconColor: _c(
        t.entryModeIconColor,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      helpTextStyle: _text(
        t.helpTextStyle,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      hourMinuteColor: mappedHourMinute,
      hourMinuteShape: _shape(t.hourMinuteShape),
      hourMinuteTextColor: _on(
        t.hourMinuteTextColor,
        hourMinute,
        mappedHourMinute,
      ),
      hourMinuteTextStyle: _text(t.hourMinuteTextStyle, _Kind.content),
      inputDecorationTheme: _inputTheme(t.inputDecorationTheme),
      shape: _shape(t.shape),
      timeSelectorSeparatorColor: _wsp(
        t.timeSelectorSeparatorColor,
        _Kind.content,
      ),
      timeSelectorSeparatorTextStyle: _wspOf(
        t.timeSelectorSeparatorTextStyle,
        (s) => _text(s, _Kind.content),
      ),
    );
  }

  ToggleButtonsThemeData _toggleButtons(ToggleButtonsThemeData t) => t.copyWith(
    textStyle: _text(t.textStyle, _Kind.content),
    color: _c(t.color, _Kind.content, PaletteToken.text),
    selectedColor: _c(t.selectedColor, _Kind.accent, PaletteToken.primary),
    disabledColor: _c(
      t.disabledColor,
      _Kind.content,
      PaletteToken.textDisabled,
    ),
    fillColor: _c(t.fillColor, _Kind.fill),
    focusColor: _c(t.focusColor, _Kind.overlay),
    highlightColor: _c(t.highlightColor, _Kind.overlay),
    hoverColor: _c(t.hoverColor, _Kind.overlay),
    splashColor: _c(t.splashColor, _Kind.overlay),
    borderColor: _c(t.borderColor, _Kind.outline, PaletteToken.border),
    selectedBorderColor: _c(t.selectedBorderColor, _Kind.outline),
    disabledBorderColor: _c(t.disabledBorderColor, _Kind.outline),
  );

  TooltipThemeData _tooltip(TooltipThemeData t) {
    final decoration = t.decoration;
    final bg = decoration is BoxDecoration ? decoration.color : null;
    final mappedDecoration = _decoration(
      decoration,
      _Kind.inverse,
      PaletteToken.inverseSurface,
    );
    final mappedBg = mappedDecoration is BoxDecoration
        ? mappedDecoration.color
        : null;
    return t.copyWith(
      decoration: mappedDecoration,
      textStyle: _text(
        t.textStyle,
        _Kind.onFill,
        PaletteToken.onInverseSurface,
        bg,
        mappedBg,
      ),
    );
  }

  // ------------------------------------------------------------------ theme

  ThemeData _theme(ThemeData t, Iterable<ThemeExtension<dynamic>> replace) {
    MenuThemeData? menu(MenuThemeData m) => m.style == null
        ? m
        : MenuThemeData(style: _menuStyle(m.style), submenuIcon: m.submenuIcon);
    final menuBar = t.menuBarTheme;
    return t.copyWith(
      colorScheme: _scheme(t.colorScheme),
      canvasColor: _map(t.canvasColor, _Kind.surface, PaletteToken.surface),
      cardColor: _map(t.cardColor, _Kind.surface, PaletteToken.surface),
      disabledColor: _map(
        t.disabledColor,
        _Kind.content,
        PaletteToken.textDisabled,
      ),
      dividerColor: _map(t.dividerColor, _Kind.outline, PaletteToken.divider),
      focusColor: _map(t.focusColor, _Kind.overlay),
      highlightColor: _map(t.highlightColor, _Kind.overlay),
      hintColor: _map(t.hintColor, _Kind.content, PaletteToken.textTertiary),
      hoverColor: _map(t.hoverColor, _Kind.overlay),
      primaryColor: _map(t.primaryColor, _Kind.fill, PaletteToken.primary),
      primaryColorDark: _map(t.primaryColorDark, _Kind.accent),
      primaryColorLight: _map(t.primaryColorLight, _Kind.container),
      scaffoldBackgroundColor: _map(
        t.scaffoldBackgroundColor,
        _Kind.surface,
        PaletteToken.background,
      ),
      secondaryHeaderColor: _map(t.secondaryHeaderColor, _Kind.container),
      shadowColor: _map(t.shadowColor, _Kind.shadow, PaletteToken.shadow),
      splashColor: _map(t.splashColor, _Kind.overlay),
      unselectedWidgetColor: _map(
        t.unselectedWidgetColor,
        _Kind.content,
        PaletteToken.textSecondary,
      ),
      textTheme: _textTheme(t.textTheme, _Kind.content, PaletteToken.text),
      primaryTextTheme: _textTheme(
        t.primaryTextTheme,
        _Kind.onFill,
        PaletteToken.onPrimary,
      ),
      iconTheme: _icon(t.iconTheme, _Kind.content, PaletteToken.text),
      primaryIconTheme: _icon(
        t.primaryIconTheme,
        _Kind.onFill,
        PaletteToken.onPrimary,
      ),
      cupertinoOverrideTheme: _cupertino(t.cupertinoOverrideTheme),
      extensions: _extensions(t, replace),
      appBarTheme: _appBar(t.appBarTheme),
      badgeTheme: _badge(t.badgeTheme),
      bannerTheme: _banner(t.bannerTheme),
      bottomAppBarTheme: _bottomAppBar(t.bottomAppBarTheme),
      bottomNavigationBarTheme: _bottomNav(t.bottomNavigationBarTheme),
      bottomSheetTheme: _bottomSheet(t.bottomSheetTheme),
      buttonTheme: _legacyButton(t),
      cardTheme: _card(t.cardTheme),
      carouselViewTheme: _carousel(t.carouselViewTheme),
      checkboxTheme: _checkbox(t.checkboxTheme),
      chipTheme: _chip(t.chipTheme),
      dataTableTheme: _dataTable(t.dataTableTheme),
      datePickerTheme: _datePicker(t.datePickerTheme),
      dialogTheme: _dialog(t.dialogTheme),
      dividerTheme: _divider(t.dividerTheme),
      drawerTheme: _drawer(t.drawerTheme),
      dropdownMenuTheme: _dropdownMenu(t.dropdownMenuTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _button(t.elevatedButtonTheme.style),
      ),
      expansionTileTheme: _expansionTile(t.expansionTileTheme),
      filledButtonTheme: FilledButtonThemeData(
        style: _button(t.filledButtonTheme.style),
      ),
      floatingActionButtonTheme: _fab(t.floatingActionButtonTheme),
      iconButtonTheme: IconButtonThemeData(
        style: _button(t.iconButtonTheme.style),
      ),
      inputDecorationTheme: _input(t.inputDecorationTheme),
      listTileTheme: _listTile(t.listTileTheme),
      menuBarTheme: menuBar.style == null
          ? menuBar
          : MenuBarThemeData(style: _menuStyle(menuBar.style)),
      menuButtonTheme: MenuButtonThemeData(
        style: _button(t.menuButtonTheme.style),
      ),
      menuTheme: menu(t.menuTheme),
      navigationBarTheme: _navigationBar(t.navigationBarTheme),
      navigationDrawerTheme: _navigationDrawer(t.navigationDrawerTheme),
      navigationRailTheme: _navigationRail(t.navigationRailTheme),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _button(t.outlinedButtonTheme.style),
      ),
      popupMenuTheme: _popupMenu(t.popupMenuTheme),
      progressIndicatorTheme: _progress(t.progressIndicatorTheme),
      radioTheme: _radio(t.radioTheme),
      scrollbarTheme: _scrollbar(t.scrollbarTheme),
      searchBarTheme: _searchBar(t.searchBarTheme),
      searchViewTheme: _searchView(t.searchViewTheme),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: _button(t.segmentedButtonTheme.style),
        selectedIcon: t.segmentedButtonTheme.selectedIcon,
      ),
      sliderTheme: _slider(t.sliderTheme),
      snackBarTheme: _snackBar(t.snackBarTheme),
      switchTheme: _switch(t.switchTheme),
      tabBarTheme: _tabBar(t.tabBarTheme),
      textButtonTheme: TextButtonThemeData(
        style: _button(t.textButtonTheme.style),
      ),
      textSelectionTheme: _textSelection(t.textSelectionTheme),
      timePickerTheme: _timePicker(t.timePickerTheme),
      toggleButtonsTheme: _toggleButtons(t.toggleButtonsTheme),
      tooltipTheme: _tooltip(t.tooltipTheme),
    );
  }
}
