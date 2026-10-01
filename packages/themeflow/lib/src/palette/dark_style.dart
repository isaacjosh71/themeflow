import 'package:flutter/foundation.dart';

/// How dark surfaces are derived.
enum DarkSurfaces {
  /// Dark surfaces with a hint of the brand hue, like Material 3.
  tinted,

  /// Pure grey surfaces.
  neutral,

  /// A black background with dark grey surfaces, for OLED screens.
  black,
}

/// Options for deriving dark colors.
///
/// Only derived colors are affected. Colors you set yourself are never
/// changed.
@immutable
class DarkStyle with Diagnosticable {
  /// Creates dark-mode options.
  const DarkStyle({
    this.surfaces = DarkSurfaces.tinted,
    this.accentLightness = 80,
  }) : assert(accentLightness >= 0 && accentLightness <= 100);

  /// How dark surfaces look.
  final DarkSurfaces surfaces;

  /// The OKLCH lightness, 0–100, that brand and status colors are raised to
  /// in dark mode.
  final double accentLightness;

  /// Returns a copy with the given options replaced.
  DarkStyle copyWith({DarkSurfaces? surfaces, double? accentLightness}) =>
      DarkStyle(
        surfaces: surfaces ?? this.surfaces,
        accentLightness: accentLightness ?? this.accentLightness,
      );

  @override
  bool operator ==(Object other) =>
      other is DarkStyle &&
      other.surfaces == surfaces &&
      other.accentLightness == accentLightness;

  @override
  int get hashCode => Object.hash(surfaces, accentLightness);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<DarkSurfaces>('surfaces', surfaces))
      ..add(DoubleProperty('accentLightness', accentLightness));
  }
}
