import 'dart:convert';

import 'package:flutter/material.dart';

/// The user's saved choice, as one small versioned JSON string.
///
/// `{"v":1,"mode":"dark"}`. A bare mode name such as `dark` is read too, so
/// an app that already saved its own mode under the same key keeps it.
@immutable
class SavedThemeState {
  /// Creates a saved state.
  const SavedThemeState({required this.mode});

  /// The current format version.
  static const int version = 1;

  /// The mode the user picked.
  final ThemeMode mode;

  /// The JSON string to save.
  String encode() => jsonEncode({'v': version, 'mode': mode.name});

  /// Reads [raw], or returns null when it's missing or unreadable.
  static SavedThemeState? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final bare = _mode(raw);
    if (bare != null) return SavedThemeState(mode: bare);
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, Object?>) return null;
      final mode = _mode(data['mode']);
      return mode == null ? null : SavedThemeState(mode: mode);
    } on FormatException {
      return null;
    }
  }

  static ThemeMode? _mode(Object? name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
