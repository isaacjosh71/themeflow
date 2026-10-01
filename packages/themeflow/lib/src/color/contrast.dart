import 'dart:ui' show Color;

import 'oklch.dart';

/// Relative luminance at which black and white have the same contrast.
///
/// Backgrounds lighter than this get darker foregrounds, and vice versa.
const double _crossover = 0.179;

/// The WCAG 2 contrast ratio between [foreground] and [background], from 1
/// to 21.
///
/// A translucent [foreground] is composited over [background] first. The
/// background is treated as opaque.
double contrastRatio(Color foreground, Color background) {
  final bg = background.withValues(alpha: 1);
  final fg = foreground.a < 1 ? Color.alphaBlend(foreground, bg) : foreground;
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

/// Returns [foreground], moved in lightness just far enough to reach
/// [minimum] contrast against [background].
///
/// Hue is kept and the smallest change is found by binary search. If
/// [minimum] can't be reached, the best possible extreme is returned.
Color ensureContrast(Color foreground, Color background, double minimum) {
  if (contrastRatio(foreground, background) >= minimum) return foreground;

  final fg = Oklch.fromColor(foreground);
  final bgL = Oklch.fromColor(background.withValues(alpha: 1)).l;
  final towardDark =
      background.withValues(alpha: 1).computeLuminance() > _crossover;
  final extreme = towardDark ? 0.0 : 1.0;

  Color at(double l) => fg.copyWith(l: l).toColor();

  if (contrastRatio(at(extreme), background) < minimum) {
    // Unreachable on this side. Offer whichever extreme reads best.
    final other = at(1 - extreme);
    final best = at(extreme);
    return contrastRatio(other, background) > contrastRatio(best, background)
        ? other
        : best;
  }

  // Contrast only grows monotonically once the foreground is on the far side
  // of the background, so start the search from whichever is further out.
  var lo = towardDark ? (fg.l < bgL ? fg.l : bgL) : (fg.l > bgL ? fg.l : bgL);
  var hi = extreme;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (contrastRatio(at(mid), background) >= minimum) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return at(hi);
}

/// Whichever of near-white or near-black (tinted with [base]'s hue) reads
/// best on [base]. White wins when it reaches 4.5:1.
Color bestOn(Color base) {
  final hue = Oklch.fromColor(base);
  final white = Color.from(alpha: 1, red: 1, green: 1, blue: 1);
  if (contrastRatio(white, base) >= 4.5) return white;
  final dark = Oklch(0.18, hue.c < 0.05 ? hue.c : 0.05, hue.h).toColor();
  return contrastRatio(dark, base) >= contrastRatio(white, base) ? dark : white;
}
