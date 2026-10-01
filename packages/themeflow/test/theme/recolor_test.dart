import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/src/color/oklch.dart';
import 'package:themeflow/themeflow.dart';

const brand = Color(0xFF3D5AFE);

/// A light theme the way real apps write them: explicit whites, greys and a
/// brand color sprinkled across component themes.
ThemeData legacyTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: brand),
  scaffoldBackgroundColor: Colors.white,
  splashColor: brand.withValues(alpha: 0.12),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xDD000000),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: brand,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFFF5F5F5),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
    ),
  ),
  cardTheme: const CardThemeData(color: Colors.white),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF212121), fontSize: 15),
    bodySmall: TextStyle(color: Color(0xFF757575)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE)),
);

class _Brand extends ThemeExtension<_Brand> implements Recolorable {
  const _Brand(this.banner);
  final Color banner;

  @override
  _Brand recolor(ColorMapper mapper) =>
      _Brand(mapper.map(banner, TokenRole.surface));

  @override
  _Brand copyWith({Color? banner}) => _Brand(banner ?? this.banner);

  @override
  _Brand lerp(_Brand? other, double t) =>
      other == null ? this : _Brand(Color.lerp(banner, other.banner, t)!);
}

class _Plain extends ThemeExtension<_Plain> {
  const _Plain(this.value);
  final int value;

  @override
  _Plain copyWith({int? value}) => _Plain(value ?? this.value);

  @override
  _Plain lerp(_Plain? other, double t) => this;
}

void main() {
  group('recolor: an existing light theme to dark', () {
    final light = legacyTheme();
    final palettes = resolvePalettes(light: ThemePalette.fromTheme(light));
    final dark = recolor(light, from: palettes.light, to: palettes.dark);

    test('backgrounds become the dark palette', () {
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, palettes.dark.background);
      expect(dark.appBarTheme.backgroundColor, palettes.dark.background);
      expect(dark.cardTheme.color, palettes.dark.surface);
      expect(dark.inputDecorationTheme.fillColor, palettes.dark.fill);
      expect(dark.dividerTheme.color, palettes.dark.divider);
      expect(dark.extension<ResolvedPalette>(), palettes.dark);
    });

    test('foregrounds stay readable on their recolored backgrounds', () {
      expect(
        contrastRatio(
          dark.appBarTheme.foregroundColor!,
          dark.appBarTheme.backgroundColor!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      final button = dark.elevatedButtonTheme.style!;
      final bg = button.backgroundColor!.resolve({})!;
      final fg = button.foregroundColor!.resolve({})!;
      expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(
          dark.textTheme.bodyMedium!.color!,
          dark.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('a brand fill gets lighter and keeps its hue', () {
      final bg = dark.elevatedButtonTheme.style!.backgroundColor!.resolve({})!;
      expect(Oklch.fromColor(bg).l, greaterThan(Oklch.fromColor(brand).l));
      expect(Oklch.fromColor(bg).h, closeTo(Oklch.fromColor(brand).h, 4));
    });

    test('everything that is not a color is kept', () {
      final shape = dark.elevatedButtonTheme.style!.shape!.resolve({});
      expect(
        shape,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      expect(dark.textTheme.bodyMedium!.fontSize, 15);
      expect(dark.inputDecorationTheme.filled, isTrue);
      expect(
        dark.inputDecorationTheme.enabledBorder,
        isA<OutlineInputBorder>(),
      );
    });

    test('alpha is kept on translucent colors', () {
      expect(dark.splashColor.a, closeTo(0.12, 0.01));
    });

    test('the borders line up with the palette', () {
      expect(
        dark.inputDecorationTheme.enabledBorder!.borderSide.color,
        palettes.dark.border,
      );
    });
  });

  group('recolor: same brightness', () {
    test('the same palette leaves the theme untouched', () {
      final light = legacyTheme();
      final p = resolvePalettes(light: ThemePalette.fromTheme(light)).light;
      final same = recolor(light, from: p, to: p);
      expect(same.copyWith(extensions: light.extensions.values), light);
    });

    test('a new palette changes token colors and leaves the rest', () {
      final light = legacyTheme();
      final inferred = ThemePalette.fromTheme(light);
      final from = resolvePalettes(light: inferred).light;
      final to = resolvePalettes(
        light: inferred.copyWith(primary: const Color(0xFF00897B)),
      ).light;
      final rebranded = recolor(light, from: from, to: to);
      expect(rebranded.colorScheme.primary, const Color(0xFF00897B));
      // The button's brand color wasn't a palette token, so it stays.
      expect(
        rebranded.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        brand,
      );
      expect(rebranded.scaffoldBackgroundColor, Colors.white);
    });
  });

  group('recolor: special colors', () {
    final p = resolvePalettes(light: const ThemePalette(primary: brand));

    test('widget-state colors still resolve per state', () {
      final theme = generateTheme(p.light).copyWith(
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.light.primary
                : p.light.surface,
          ),
        ),
      );
      final dark = recolor(theme, from: p.light, to: p.dark);
      final fill = dark.checkboxTheme.fillColor!;
      expect(fill.resolve({WidgetState.selected}), p.dark.primary);
      expect(fill.resolve({}), p.dark.surface);
    });

    test('a ColorToken inside a theme resolves for the new palette', () {
      const gold = ColorToken(0xFFC9A227, id: 'gold');
      final theme = generateTheme(
        p.light,
      ).copyWith(dividerTheme: const DividerThemeData(color: gold));
      final dark = recolor(theme, from: p.light, to: p.dark);
      expect(dark.dividerTheme.color, p.dark.resolve(gold));
    });

    test('Cupertino dynamic colors are left to resolve themselves', () {
      final theme = generateTheme(p.light).copyWith(
        cupertinoOverrideTheme: const CupertinoThemeData(
          primaryColor: CupertinoColors.systemBlue,
        ),
      );
      final dark = recolor(theme, from: p.light, to: p.dark);
      expect(
        dark.cupertinoOverrideTheme!.primaryColor,
        CupertinoColors.systemBlue,
      );
    });

    test(
      'extensions: Recolorable ones are mapped, others kept or replaced',
      () {
        final theme = generateTheme(p.light).copyWith(
          extensions: [
            p.light,
            const _Brand(Color(0xFFFFFFFF)),
            const _Plain(1),
          ],
        );
        final dark = recolor(theme, from: p.light, to: p.dark);
        expect(dark.extension<_Brand>()!.banner, p.dark.surface);
        expect(dark.extension<_Plain>()!.value, 1);
        expect(dark.extension<ResolvedPalette>(), p.dark);

        final replaced = recolor(
          theme,
          from: p.light,
          to: p.dark,
          extensions: const [_Plain(2)],
        );
        expect(replaced.extension<_Plain>()!.value, 2);
      },
    );
  });

  group('generateTheme', () {
    final p = resolvePalettes(light: const ThemePalette(primary: brand));

    test('builds a complete Material 3 theme with the palette inside', () {
      final theme = generateTheme(p.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, brand);
      expect(theme.scaffoldBackgroundColor, p.light.background);
      expect(theme.extension<ResolvedPalette>(), p.light);
      expect(generateTheme(p.dark).brightness, Brightness.dark);
    });

    test('recoloring a generated theme gives the generated dark scheme', () {
      final dark = recolor(generateTheme(p.light), from: p.light, to: p.dark);
      expect(dark.colorScheme, schemeFromPalette(p.dark));
    });

    test('reading a generated theme back gives the same core colors', () {
      final back = ThemePalette.fromTheme(generateTheme(p.light));
      expect(back.primary, p.light.primary);
      expect(back.background, p.light.background);
      expect(back.surface, p.light.surface);
      expect(back.surfaceElevated, p.light.surfaceElevated);
      expect(back.fill, p.light.fill);
      expect(back.text, p.light.text);
      expect(back.textSecondary, p.light.textSecondary);
      expect(back.textTertiary, p.light.textTertiary);
      expect(back.divider, p.light.divider);
    });
  });
}
