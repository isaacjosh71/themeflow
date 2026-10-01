import 'dart:math' as math;
import 'dart:ui' show Color, ColorSpace;

import 'package:flutter/foundation.dart';

/// A color in OKLCH: perceptual lightness, chroma and hue.
///
/// OKLCH is the polar form of Björn Ottosson's OKLab. Unlike HSL, equal
/// lightness looks equally light across hues, so lightness rules give even
/// results for every brand color.
@immutable
class Oklch {
  /// Creates a color from lightness [l] (0–1), chroma [c] (0 to about 0.37),
  /// hue [h] in degrees and [alpha] (0–1).
  const Oklch(this.l, this.c, this.h, [this.alpha = 1.0]);

  /// Converts an sRGB [color]. Colors in other color spaces are converted to
  /// sRGB first.
  factory Oklch.fromColor(Color color) {
    final srgb = color.colorSpace == ColorSpace.sRGB
        ? color
        : color.withValues(colorSpace: ColorSpace.sRGB);
    final (l, a, b) = _linearToOklab(
      _toLinear(srgb.r),
      _toLinear(srgb.g),
      _toLinear(srgb.b),
    );
    final c = math.sqrt(a * a + b * b);
    var h = math.atan2(b, a) * 180 / math.pi;
    if (h < 0) h += 360;
    // Hue is meaningless for greys; pin it so results are deterministic.
    return Oklch(l, c, c < 1e-4 ? 0 : h, srgb.a);
  }

  /// Perceptual lightness, 0 (black) to 1 (white).
  final double l;

  /// Chroma: 0 is grey; vivid sRGB colors reach about 0.3.
  final double c;

  /// Hue angle in degrees, 0–360.
  final double h;

  /// Opacity, 0–1.
  final double alpha;

  /// Returns a copy with the given values replaced.
  Oklch copyWith({double? l, double? c, double? h, double? alpha}) =>
      Oklch(l ?? this.l, c ?? this.c, h ?? this.h, alpha ?? this.alpha);

  /// Converts back to an sRGB [Color].
  ///
  /// Out-of-gamut colors are brought into sRGB by reducing chroma while
  /// keeping lightness and hue, so a color never shifts hue to fit.
  Color toColor() {
    final lightness = l.clamp(0.0, 1.0);
    if (lightness >= 1 - 1e-6) return _opaque(1, 1, 1);
    if (lightness <= 1e-6) return _opaque(0, 0, 0);
    var chroma = math.max(0.0, c);
    var rgb = _oklchToLinear(lightness, chroma, h);
    if (!_inGamut(rgb)) {
      var lo = 0.0;
      var hi = chroma;
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        if (_inGamut(_oklchToLinear(lightness, mid, h))) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      chroma = lo;
      rgb = _oklchToLinear(lightness, chroma, h);
    }
    final (r, g, b) = rgb;
    return _opaque(_toGamma(r), _toGamma(g), _toGamma(b));
  }

  Color _opaque(double r, double g, double b) => Color.from(
    alpha: alpha.clamp(0.0, 1.0),
    red: r.clamp(0.0, 1.0),
    green: g.clamp(0.0, 1.0),
    blue: b.clamp(0.0, 1.0),
  );

  @override
  bool operator ==(Object other) =>
      other is Oklch &&
      other.l == l &&
      other.c == c &&
      other.h == h &&
      other.alpha == alpha;

  @override
  int get hashCode => Object.hash(l, c, h, alpha);

  @override
  String toString() =>
      'Oklch(${l.toStringAsFixed(3)}, ${c.toStringAsFixed(3)}, '
      '${h.toStringAsFixed(1)}${alpha < 1 ? ', ${alpha.toStringAsFixed(2)}' : ''})';
}

const double _gamutEpsilon = 1e-5;

bool _inGamut((double, double, double) rgb) {
  final (r, g, b) = rgb;
  return r >= -_gamutEpsilon &&
      r <= 1 + _gamutEpsilon &&
      g >= -_gamutEpsilon &&
      g <= 1 + _gamutEpsilon &&
      b >= -_gamutEpsilon &&
      b <= 1 + _gamutEpsilon;
}

double _toLinear(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _toGamma(double linear) {
  final v = linear.clamp(0.0, 1.0);
  return v <= 0.0031308
      ? 12.92 * v
      : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
}

double _cbrt(double v) =>
    v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

(double, double, double) _linearToOklab(double r, double g, double b) {
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

(double, double, double) _oklchToLinear(double lightness, double c, double h) {
  final radians = h * math.pi / 180;
  final a = c * math.cos(radians);
  final b = c * math.sin(radians);
  final l = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final m = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final s = lightness - 0.0894841775 * a - 1.2914855480 * b;
  final l3 = l * l * l;
  final m3 = m * m * m;
  final s3 = s * s * s;
  return (
    4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
    -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
    -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
  );
}
