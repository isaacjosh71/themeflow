import 'package:flutter/painting.dart';
import 'package:themeflow/themeflow.dart';

/// Colors of the app's own, as tokens. Each is still a plain `Color` (its
/// light value), so old code using them keeps working; `.of(context)` makes
/// a call site follow the theme.
abstract final class AppColors {
  /// Dark value derived from the role (accent by default).
  static const gold = ColorToken(0xFFB8860B, id: 'gold');

  /// Dark value given explicitly.
  static const page = ColorToken(
    0xFFF4ECD8,
    id: 'page',
    role: TokenRole.surface,
    dark: Color(0xFF221E17),
  );

  /// Text on [page].
  static const ink = ColorToken(0xFF3E2723, id: 'ink', role: TokenRole.content);
}
