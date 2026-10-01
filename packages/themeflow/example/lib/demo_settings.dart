import 'package:flutter/material.dart';
import 'package:themeflow/themeflow.dart';

import 'app_theme.dart';

/// What the Settings tab lets you play with. Not part of themeflow: in your
/// app these would be fixed values in code.
class DemoSettings extends ChangeNotifier {
  bool _fromExistingTheme = true;
  Color _brand = AppTheme.brand;
  DarkSurfaces _surfaces = DarkSurfaces.tinted;

  /// True: recolor AppTheme.light. False: generate a theme from the brand.
  bool get fromExistingTheme => _fromExistingTheme;
  set fromExistingTheme(bool value) {
    _fromExistingTheme = value;
    notifyListeners();
  }

  Color get brand => _brand;
  set brand(Color value) {
    _brand = value;
    notifyListeners();
  }

  DarkSurfaces get surfaces => _surfaces;
  set surfaces(DarkSurfaces value) {
    _surfaces = value;
    notifyListeners();
  }
}
