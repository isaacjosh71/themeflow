import 'package:flutter/widgets.dart';

import 'resolved_palette.dart';

/// What a color is for.
///
/// Roles tell themeflow how to carry a color into the other brightness, so
/// dark mode never just inverts it.
enum TokenRole {
  /// Something content sits on: backgrounds, cards, panels. In dark mode it
  /// turns dark, slightly lighter than the background.
  surface,

  /// Text and icons on a surface. In dark mode it turns light, with contrast
  /// enforced against the background.
  content,

  /// Borders and dividers.
  outline,

  /// A saturated brand or status color, used as a fill or as text. In dark
  /// mode it gets lighter and slightly calmer.
  accent,

  /// A soft tinted background, such as a chip or a banner.
  container,

  /// Text and icons on an accent or a container.
  onColor,

  /// Never changes between modes: logos, photo overlays, scrims.
  fixed,
}

/// A color of your own that follows the theme.
///
/// ```dart
/// abstract final class AppColors {
///   static const gold = ColorToken(0xFFC9A227, id: 'gold');
///   static const page = ColorToken(0xFFF4ECD8, id: 'page',
///       role: TokenRole.surface, dark: Color(0xFF1E1A14));
/// }
///
/// Icon(Icons.star, color: AppColors.gold.of(context));
/// ```
///
/// A `ColorToken` is a [Color] whose value is the light color, the same way
/// Flutter's `ColorSwatch` is a `Color`. Code that already uses
/// `AppColors.gold` as a plain color keeps compiling and looks exactly as it
/// did. Add `.of(context)` at each call site, one at a time, to make it follow
/// the theme.
///
/// The dark value is [dark] when you give one. Otherwise it's derived from the
/// light value and [role].
@immutable
class ColorToken extends Color {
  /// Creates a token whose light value is [value], an `0xAARRGGBB` integer
  /// like `Color(0xFFC9A227)` takes.
  const ColorToken(
    super.value, {
    required this.id,
    this.role = TokenRole.accent,
    this.dark,
  });

  /// A stable name for this token, unique within your app.
  ///
  /// Runtime overrides are saved under it.
  final String id;

  /// What the color is for. It decides how the dark value is derived.
  final TokenRole role;

  /// The dark value. When null, it's derived from the light value and [role].
  final Color? dark;

  /// The light value as a plain [Color].
  Color get light =>
      Color.from(alpha: a, red: r, green: g, blue: b, colorSpace: colorSpace);

  /// The token's value in the current theme.
  ///
  /// Widgets that call this rebuild when the theme changes, and the color
  /// animates with the switch.
  Color of(BuildContext context) => ResolvedPalette.of(context).resolve(this);

  // Color's own equality only compares runtime type and value, which can't
  // tell two tokens apart, and would miss a changed dark value on hot reload.
  @override
  bool operator ==(Object other) =>
      other is ColorToken &&
      other.id == id &&
      other.toARGB32() == toARGB32() &&
      other.dark == dark &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, toARGB32(), dark, role);

  @override
  String toString() =>
      'ColorToken($id, 0x${toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()})';
}
