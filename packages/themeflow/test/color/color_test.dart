import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/src/color/contrast.dart';
import 'package:themeflow/src/color/oklch.dart';

void main() {
  group('Oklch', () {
    test('white and black sit at the ends of the lightness scale', () {
      expect(Oklch.fromColor(const Color(0xFFFFFFFF)).l, closeTo(1, 1e-4));
      expect(Oklch.fromColor(const Color(0xFF000000)).l, closeTo(0, 1e-4));
      expect(Oklch.fromColor(const Color(0xFF808080)).c, closeTo(0, 1e-4));
    });

    test('matches the published OKLCH value of sRGB red', () {
      final red = Oklch.fromColor(const Color(0xFFFF0000));
      expect(red.l, closeTo(0.6280, 1e-3));
      expect(red.c, closeTo(0.2577, 1e-3));
      expect(red.h, closeTo(29.23, 0.1));
    });

    test('round-trips 2,000 random colors to the same 8-bit value', () {
      final random = math.Random(7);
      for (var i = 0; i < 2000; i++) {
        final color = Color(0xFF000000 | random.nextInt(0xFFFFFF));
        final back = Oklch.fromColor(color).toColor();
        expect(back.toARGB32(), color.toARGB32(), reason: '$color');
      }
    });

    test('keeps alpha', () {
      final c = Oklch.fromColor(const Color(0x80336699)).toColor();
      expect(c.a, closeTo(0x80 / 255, 1e-6));
    });

    test('gamut mapping reduces chroma and keeps hue', () {
      // Far outside sRGB: very light and very saturated.
      const wild = Oklch(0.9, 0.35, 264);
      final mapped = Oklch.fromColor(wild.toColor());
      expect(mapped.l, closeTo(0.9, 0.01));
      expect(mapped.c, lessThan(0.35));
      expect(mapped.h, closeTo(264, 2));
    });
  });

  group('contrastRatio', () {
    test('black on white is 21:1 and a color on itself is 1:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 1e-6),
      );
      expect(
        contrastRatio(const Color(0xFF3D5AFE), const Color(0xFF3D5AFE)),
        closeTo(1, 1e-9),
      );
    });

    test('matches the well-known #767676 on white threshold (4.54:1)', () {
      expect(
        contrastRatio(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        closeTo(4.54, 0.01),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFF1E88E5);
      const b = Color(0xFFFFF8E1);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-12));
    });

    test('composites a translucent foreground first', () {
      const bg = Color(0xFFFFFFFF);
      final half = const Color(0xFF000000).withValues(alpha: 0.5);
      expect(contrastRatio(half, bg), lessThan(21));
      expect(contrastRatio(half, bg), greaterThan(3));
    });
  });

  group('ensureContrast', () {
    test('leaves a passing color alone', () {
      const fg = Color(0xFF111111);
      expect(ensureContrast(fg, const Color(0xFFFFFFFF), 4.5), fg);
    });

    test('reaches the minimum with a small change', () {
      const bg = Color(0xFFFFFFFF);
      const fg = Color(0xFF9E9E9E); // about 2.7:1 on white
      final fixed = ensureContrast(fg, bg, 4.5);
      final ratio = contrastRatio(fixed, bg);
      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(ratio, lessThan(4.7), reason: 'should be the smallest change');
    });

    test('goes lighter on dark backgrounds and keeps the hue', () {
      const bg = Color(0xFF121212);
      const fg = Color(0xFF1A3A8F); // dark blue on near-black
      final fixed = ensureContrast(fg, bg, 4.5);
      expect(contrastRatio(fixed, bg), greaterThanOrEqualTo(4.5));
      expect(Oklch.fromColor(fixed).l, greaterThan(Oklch.fromColor(fg).l));
      expect(Oklch.fromColor(fixed).h, closeTo(Oklch.fromColor(fg).h, 3));
    });

    test('crosses over when the foreground starts on the wrong side', () {
      const bg = Color(0xFFE0E0E0);
      const fg = Color(0xFFF5F5F5); // lighter than a light background
      final fixed = ensureContrast(fg, bg, 4.5);
      expect(contrastRatio(fixed, bg), greaterThanOrEqualTo(4.5));
    });

    test('returns the best extreme when the target is impossible', () {
      const bg = Color(0xFF777777);
      final fixed = ensureContrast(const Color(0xFF888888), bg, 21);
      expect(contrastRatio(fixed, bg), greaterThan(4));
    });
  });

  group('bestOn', () {
    test('white on saturated blue, near-black on yellow', () {
      expect(bestOn(const Color(0xFF3D5AFE)), const Color(0xFFFFFFFF));
      final onYellow = bestOn(const Color(0xFFFFEB3B));
      expect(contrastRatio(onYellow, const Color(0xFFFFEB3B)), greaterThan(10));
    });
  });
}
