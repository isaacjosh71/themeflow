import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/src/color/oklch.dart';
import 'package:themeflow/themeflow.dart';

const brand = Color(0xFF3D5AFE);

void main() {
  group('resolvePalettes', () {
    test('one brand color is enough for both modes', () {
      final p = resolvePalettes(light: const ThemePalette(primary: brand));
      expect(p.light.brightness, Brightness.light);
      expect(p.dark.brightness, Brightness.dark);
      expect(p.light.primary, brand);
      // Dark primary is lighter, same hue family.
      final lightP = Oklch.fromColor(p.light.primary);
      final darkP = Oklch.fromColor(p.dark.primary);
      expect(darkP.l, greaterThan(lightP.l));
      expect(darkP.h, closeTo(lightP.h, 4));
      // Dark surfaces are dark and step up with elevation.
      final bg = Oklch.fromColor(p.dark.background).l;
      final card = Oklch.fromColor(p.dark.surface).l;
      final dialog = Oklch.fromColor(p.dark.surfaceElevated).l;
      expect(bg, lessThan(0.25));
      expect(card, greaterThan(bg));
      expect(dialog, greaterThan(card));
    });

    test('colors you set are never changed', () {
      const light = ThemePalette(
        primary: Color(0xFFFFEB3B), // a yellow that fails 3:1 on white
        background: Color(0xFFFFFFFF),
        text: Color(0xFF777777), // 4.48:1, just under AA
      );
      final p = resolvePalettes(light: light);
      expect(p.light.primary, light.primary);
      expect(p.light.background, light.background);
      expect(p.light.text, light.text);
      // …and the report says what's wrong with them.
      final failing = p.light.contrastReport().failures.map(
        (c) => c.foreground,
      );
      expect(failing, containsAll([PaletteToken.primary, PaletteToken.text]));
    });

    test('a partial dark palette overrides only what it sets', () {
      final p = resolvePalettes(
        light: const ThemePalette(primary: brand),
        dark: const ThemePalette(background: Color(0xFF000000)),
      );
      expect(p.dark.background, const Color(0xFF000000));
      expect(p.dark.primary, isNot(brand));
      expect(p.dark.contrastReport().failures, isEmpty);
    });

    test('a dark-only palette derives the light one', () {
      final p = resolvePalettes(
        dark: const ThemePalette(
          primary: Color(0xFF90CAF9),
          background: Color(0xFF101418),
        ),
      );
      expect(Oklch.fromColor(p.light.background).l, greaterThan(0.9));
      expect(p.light.contrastReport().failures, isEmpty);
    });

    test('a seed palette uses Flutter\'s fromSeed for both modes', () {
      final p = resolvePalettes(light: const ThemePalette.seed(brand));
      final light = ColorScheme.fromSeed(
        seedColor: brand,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      final dark = ColorScheme.fromSeed(
        seedColor: brand,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      expect(p.light.primary, light.primary);
      expect(p.light.background, light.surface);
      expect(p.dark.primary, dark.primary);
      expect(p.dark.surfaceElevated, dark.surfaceContainerHigh);
    });

    test('black surfaces give a pure black background', () {
      final p = resolvePalettes(
        light: const ThemePalette(primary: brand),
        style: const DarkStyle(surfaces: DarkSurfaces.black),
      );
      expect(p.dark.background.toARGB32(), 0xFF000000);
    });

    test('neutral surfaces are pure greys', () {
      final p = resolvePalettes(
        light: const ThemePalette(primary: brand),
        style: const DarkStyle(surfaces: DarkSurfaces.neutral),
      );
      for (final t in [
        PaletteToken.background,
        PaletteToken.surface,
        PaletteToken.surfaceElevated,
        PaletteToken.fill,
      ]) {
        expect(Oklch.fromColor(p.dark[t]).c, lessThan(0.003), reason: '$t');
      }
    });

    test('same input gives equal palettes (so themes can be cached)', () {
      final a = resolvePalettes(light: const ThemePalette(primary: brand));
      final b = resolvePalettes(light: const ThemePalette(primary: brand));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('throws a clear error without a primary color', () {
      expect(
        () => resolvePalettes(light: const ThemePalette()),
        throwsArgumentError,
      );
    });

    // The promise of §6: whatever the brand color, every color themeflow
    // derives meets its contrast minimum, in both modes and every style.
    test(
      'every derived pair meets its minimum for 1,000 random brand colors',
      () {
        final random = math.Random(42);
        for (var i = 0; i < 1000; i++) {
          final style = DarkSurfaces.values[i % DarkSurfaces.values.length];
          {
            final color = Color(0xFF000000 | random.nextInt(0xFFFFFF));
            final p = resolvePalettes(
              light: ThemePalette(primary: color),
              style: DarkStyle(surfaces: style),
            );
            // In light mode only primary was given, so only it may fail.
            final lightFailures = p.light.contrastReport().failures.where(
              (c) => c.foreground != PaletteToken.primary,
            );
            expect(lightFailures, isEmpty, reason: '$color light');
            expect(
              p.dark.contrastReport().failures,
              isEmpty,
              reason: '$color dark ($style)',
            );
          }
        }
      },
    );
  });

  group('ThemePalette.fromTheme', () {
    test('reads the main colors of a theme', () {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        cardTheme: const CardThemeData(color: Color(0xFFFFFFFF)),
        dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0)),
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Color(0xFFF0F0F0),
        ),
      );
      final palette = ThemePalette.fromTheme(theme);
      expect(palette.primary, theme.colorScheme.primary);
      expect(palette.background, const Color(0xFFF7F7F5));
      expect(palette.surface, const Color(0xFFFFFFFF));
      expect(palette.divider, const Color(0xFFE0E0E0));
      expect(palette.fill, const Color(0xFFF0F0F0));
      expect(palette.text, theme.colorScheme.onSurface);
    });
  });

  group('ColorToken', () {
    const gold = ColorToken(0xFFC9A227, id: 'gold');
    const page = ColorToken(
      0xFFF4ECD8,
      id: 'page',
      role: TokenRole.surface,
      dark: Color(0xFF1E1A14),
    );
    const ink = ColorToken(0xFF3E2723, id: 'ink', role: TokenRole.content);

    test('is a Color with its light value', () {
      const Color asColor = gold;
      expect(asColor.toARGB32(), 0xFFC9A227);
    });

    test('equality uses the id and the values', () {
      expect(gold, const ColorToken(0xFFC9A227, id: 'gold'));
      expect(gold, isNot(const ColorToken(0xFFC9A227, id: 'mustard')));
      expect(gold, isNot(const Color(0xFFC9A227)));
    });

    test('resolves per palette', () {
      final p = resolvePalettes(light: const ThemePalette(primary: brand));
      expect(p.light.resolve(gold), gold.light);
      expect(p.dark.resolve(page), const Color(0xFF1E1A14));
      // Derived: an accent reads at 3:1 and content at 4.5:1 on the dark
      // background.
      expect(
        contrastRatio(p.dark.resolve(gold), p.dark.background),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrastRatio(p.dark.resolve(ink), p.dark.background),
        greaterThanOrEqualTo(4.5),
      );
      // Cached: the same instance comes back.
      expect(identical(p.dark.resolve(ink), p.dark.resolve(ink)), isTrue);
    });

    test('withTokens overrides a token', () {
      final p = resolvePalettes(light: const ThemePalette(primary: brand));
      final custom = p.dark.withTokens({gold: const Color(0xFFFFD54F)});
      expect(custom.resolve(gold), const Color(0xFFFFD54F));
      expect(custom.background, p.dark.background);
    });
  });

  group('ResolvedPalette.lerp', () {
    final p = resolvePalettes(light: const ThemePalette(primary: brand));
    const gold = ColorToken(0xFFC9A227, id: 'gold');

    test('returns the ends exactly', () {
      expect(identical(p.light.lerp(p.dark, 0), p.light), isTrue);
      expect(identical(p.light.lerp(p.dark, 1), p.dark), isTrue);
    });

    test('blends tokens and custom tokens in between', () {
      final mid = p.light.lerp(p.dark, 0.5);
      expect(
        mid.background,
        Color.lerp(p.light.background, p.dark.background, 0.5),
      );
      expect(
        mid.resolve(gold),
        Color.lerp(p.light.resolve(gold), p.dark.resolve(gold), 0.5),
      );
    });
  });
}
