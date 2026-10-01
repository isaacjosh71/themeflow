import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/themeflow.dart';

import 'busy_theme.dart';

/// The color-carrying properties each component theme reports in Flutter
/// 3.44, as seen through its diagnostics. If Flutter adds one, the guard test
/// below fails: handle the new field in lib/src/theme/recolor.dart, rerun
/// tool/generate_busy_theme.py, then add the name here.
const Map<String, Set<String>> knownColorFields = {
  'inputDecorationTheme': {
    'labelStyle',
    'floatingLabelStyle',
    'helperStyle',
    'hintStyle',
    'errorStyle',
    'iconColor',
    'prefixIconColor',
    'prefixStyle',
    'suffixIconColor',
    'suffixStyle',
    'counterStyle',
    'fillColor',
    'activeIndicatorBorder',
    'outlineBorder',
    'focusColor',
    'hoverColor',
    'errorBorder',
    'focusedBorder',
    'focusedErrorBorder',
    'disabledBorder',
    'enabledBorder',
    'border',
  },
  'scrollbarTheme': {'thumbColor', 'trackColor', 'trackBorderColor'},
  'iconTheme': {'color'},
  'primaryIconTheme': {'color'},
  'primaryTextTheme': {
    'displayLarge',
    'displayMedium',
    'displaySmall',
    'headlineLarge',
    'headlineMedium',
    'headlineSmall',
    'titleLarge',
    'titleMedium',
    'titleSmall',
    'bodyLarge',
    'bodyMedium',
    'bodySmall',
    'labelLarge',
    'labelMedium',
    'labelSmall',
  },
  'textTheme': {
    'displayLarge',
    'displayMedium',
    'displaySmall',
    'headlineLarge',
    'headlineMedium',
    'headlineSmall',
    'titleLarge',
    'titleMedium',
    'titleSmall',
    'bodyLarge',
    'bodyMedium',
    'bodySmall',
    'labelLarge',
    'labelMedium',
    'labelSmall',
  },
  'appBarTheme': {
    'backgroundColor',
    'foregroundColor',
    'shadowColor',
    'surfaceTintColor',
    'shape',
    'iconTheme',
    'actionsIconTheme',
    'toolbarTextStyle',
    'titleTextStyle',
    'systemOverlayStyle',
  },
  'badgeTheme': {'backgroundColor', 'textColor', 'textStyle'},
  'bannerTheme': {
    'backgroundColor',
    'surfaceTintColor',
    'shadowColor',
    'dividerColor',
    'contentTextStyle',
  },
  'bottomAppBarTheme': {'color', 'surfaceTintColor', 'shadowColor'},
  'bottomNavigationBarTheme': {
    'backgroundColor',
    'selectedIconTheme',
    'unselectedIconTheme',
    'selectedItemColor',
    'unselectedItemColor',
    'selectedLabelStyle',
    'unselectedLabelStyle',
  },
  'bottomSheetTheme': {
    'backgroundColor',
    'surfaceTintColor',
    'modalBackgroundColor',
    'shadowColor',
    'modalBarrierColor',
    'shape',
    'dragHandleColor',
  },
  'buttonTheme': {
    'shape',
    'buttonColor',
    'disabledColor',
    'focusColor',
    'hoverColor',
    'highlightColor',
    'splashColor',
    'colorScheme',
  },
  'cardTheme': {'color', 'shadowColor', 'surfaceTintColor', 'shape'},
  'carouselViewTheme': {'backgroundColor', 'shape', 'overlayColor'},
  'checkboxTheme': {'fillColor', 'checkColor', 'overlayColor', 'shape', 'side'},
  'chipTheme': {
    'color',
    'backgroundColor',
    'deleteIconColor',
    'disabledColor',
    'selectedColor',
    'secondarySelectedColor',
    'shadowColor',
    'surfaceTintColor',
    'selectedShadowColor',
    'checkMarkColor',
    'side',
    'shape',
    'labelStyle',
    'secondaryLabelStyle',
    'iconTheme',
  },
  'dataTableTheme': {
    'decoration',
    'dataRowColor',
    'dataTextStyle',
    'headingRowColor',
    'headingTextStyle',
  },
  'datePickerTheme': {
    'backgroundColor',
    'shadowColor',
    'surfaceTintColor',
    'shape',
    'headerBackgroundColor',
    'headerForegroundColor',
    'headerHeadlineStyle',
    'headerHelpStyle',
    'weekDayStyle',
    'dayStyle',
    'dayForegroundColor',
    'dayBackgroundColor',
    'dayOverlayColor',
    'dayShape',
    'todayForegroundColor',
    'todayBackgroundColor',
    'todayBorder',
    'yearStyle',
    'yearForegroundColor',
    'yearBackgroundColor',
    'yearOverlayColor',
    'yearShape',
    'rangePickerBackgroundColor',
    'rangePickerShadowColor',
    'rangePickerSurfaceTintColor',
    'rangePickerShape',
    'rangePickerHeaderBackgroundColor',
    'rangePickerHeaderForegroundColor',
    'rangePickerHeaderHeadlineStyle',
    'rangePickerHeaderHelpStyle',
    'rangeSelectionBackgroundColor',
    'rangeSelectionOverlayColor',
    'dividerColor',
    'inputDecorationTheme',
    'cancelButtonStyle',
    'confirmButtonStyle',
    'toggleButtonTextStyle',
    'subHeaderForegroundColor',
  },
  'dialogTheme': {
    'backgroundColor',
    'shadowColor',
    'surfaceTintColor',
    'shape',
    'iconColor',
    'titleTextStyle',
    'contentTextStyle',
    'barrierColor',
  },
  'dividerTheme': {'color'},
  'drawerTheme': {
    'backgroundColor',
    'scrimColor',
    'shadowColor',
    'surfaceTintColor',
    'shape',
    'endShape',
  },
  'dropdownMenuTheme': {
    'textStyle',
    'inputDecorationThemeData',
    'menuStyle',
    'disabledColor',
  },
  'elevatedButtonTheme': {'style'},
  'expansionTileTheme': {
    'backgroundColor',
    'collapsedBackgroundColor',
    'iconColor',
    'collapsedIconColor',
    'textColor',
    'collapsedTextColor',
    'shape',
    'collapsedShape',
  },
  'filledButtonTheme': {'style'},
  'floatingActionButtonTheme': {
    'foregroundColor',
    'backgroundColor',
    'focusColor',
    'hoverColor',
    'splashColor',
    'shape',
    'extendedTextStyle',
  },
  'iconButtonTheme': {'style'},
  'listTileTheme': {
    'shape',
    'selectedColor',
    'iconColor',
    'textColor',
    'titleTextStyle',
    'subtitleTextStyle',
    'leadingAndTrailingTextStyle',
    'tileColor',
    'selectedTileColor',
  },
  'menuBarTheme': {'style'},
  'menuButtonTheme': {'style'},
  'menuTheme': {'style'},
  'navigationBarTheme': {
    'backgroundColor',
    'shadowColor',
    'surfaceTintColor',
    'indicatorColor',
    'indicatorShape',
    'labelTextStyle',
    'iconTheme',
    'overlayColor',
  },
  'navigationDrawerTheme': {
    'backgroundColor',
    'shadowColor',
    'surfaceTintColor',
    'indicatorColor',
    'indicatorShape',
    'labelTextStyle',
    'iconTheme',
  },
  'navigationRailTheme': {
    'backgroundColor',
    'unselectedLabelTextStyle',
    'selectedLabelTextStyle',
    'unselectedIconTheme',
    'selectedIconTheme',
    'indicatorColor',
    'indicatorShape',
  },
  'outlinedButtonTheme': {'style'},
  'popupMenuTheme': {
    'color',
    'shape',
    'shadowColor',
    'surfaceTintColor',
    'text style',
    'labelTextStyle',
    'iconColor',
  },
  'progressIndicatorTheme': {
    'color',
    'linearTrackColor',
    'circularTrackColor',
    'refreshBackgroundColor',
    'stopIndicatorColor',
  },
  'radioTheme': {'fillColor', 'overlayColor', 'backgroundColor', 'side'},
  'searchBarTheme': {
    'backgroundColor',
    'shadowColor',
    'surfaceTintColor',
    'overlayColor',
    'side',
    'shape',
    'textStyle',
    'hintStyle',
  },
  'searchViewTheme': {
    'backgroundColor',
    'surfaceTintColor',
    'side',
    'shape',
    'headerTextStyle',
    'headerHintStyle',
    'dividerColor',
  },
  'segmentedButtonTheme': {'style'},
  'sliderTheme': {
    'activeTrackColor',
    'inactiveTrackColor',
    'secondaryActiveTrackColor',
    'disabledActiveTrackColor',
    'disabledInactiveTrackColor',
    'disabledSecondaryActiveTrackColor',
    'activeTickMarkColor',
    'inactiveTickMarkColor',
    'disabledActiveTickMarkColor',
    'disabledInactiveTickMarkColor',
    'thumbColor',
    'overlappingShapeStrokeColor',
    'disabledThumbColor',
    'overlayColor',
    'valueIndicatorColor',
    'valueIndicatorStrokeColor',
    'valueIndicatorTextStyle',
  },
  'snackBarTheme': {
    'backgroundColor',
    'actionTextColor',
    'disabledActionTextColor',
    'contentTextStyle',
    'shape',
    'closeIconColor',
    'actionBackgroundColor',
    'disabledActionBackgroundColor',
  },
  'switchTheme': {
    'thumbColor',
    'trackColor',
    'trackOutlineColor',
    'overlayColor',
  },
  'tabBarTheme': {
    'indicator',
    'indicatorColor',
    'dividerColor',
    'labelColor',
    'labelStyle',
    'unselectedLabelColor',
    'unselectedLabelStyle',
    'overlayColor',
  },
  'textButtonTheme': {'style'},
  'textSelectionTheme': {
    'cursorColor',
    'selectionColor',
    'selectionHandleColor',
  },
  'timePickerTheme': {
    'backgroundColor',
    'cancelButtonStyle',
    'confirmButtonStyle',
    'dayPeriodBorderSide',
    'dayPeriodColor',
    'dayPeriodShape',
    'dayPeriodTextColor',
    'dayPeriodTextStyle',
    'dialBackgroundColor',
    'dialHandColor',
    'dialTextColor',
    'dialTextStyle',
    'entryModeIconColor',
    'helpTextStyle',
    'hourMinuteColor',
    'hourMinuteShape',
    'hourMinuteTextColor',
    'hourMinuteTextStyle',
    'inputDecorationTheme',
    'shape',
    'timeSelectorSeparatorColor',
    'timeSelectorSeparatorTextStyle',
  },
  'toggleButtonsTheme': {
    'color',
    'selectedColor',
    'disabledColor',
    'fillColor',
    'focusColor',
    'highlightColor',
    'hoverColor',
    'splashColor',
    'borderColor',
    'selectedBorderColor',
    'disabledBorderColor',
  },
  'tooltipTheme': {'decoration', 'textStyle'},
};

final _colorish = RegExp(
  r'Color|TextStyle|BorderSide|IconThemeData|ButtonStyle|MenuStyle|Decoration|'
  r'ShapeBorder|OutlinedBorder|InputBorder|SystemUiOverlayStyle|InputDecorationTheme',
);

const _states = <Set<WidgetState>>[
  {},
  {WidgetState.selected},
  {WidgetState.pressed},
  {WidgetState.hovered},
  {WidgetState.focused},
  {WidgetState.disabled},
  {WidgetState.error},
];

/// Every color reachable from [value], with the path it was found at.
List<(String, Color)> collectColors(Object? value, String path) {
  final out = <(String, Color)>[];
  void visit(String p, Object? v, int depth) {
    if (v == null || depth > 8) return;
    switch (v) {
      case WidgetStateProperty<Object?>():
        for (final states in _states) {
          visit('$p$states', v.resolve(states), depth + 1);
        }
      case Color():
        out.add((p, v));
      case TextStyle():
        visit('$p.color', v.color, depth + 1);
        visit('$p.backgroundColor', v.backgroundColor, depth + 1);
        visit('$p.decorationColor', v.decorationColor, depth + 1);
      case BorderSide():
        if (v.style != BorderStyle.none) visit('$p.color', v.color, depth + 1);
      case IconThemeData():
        visit('$p.color', v.color, depth + 1);
      case InputBorder():
        visit('$p.borderSide', v.borderSide, depth + 1);
      case OutlinedBorder():
        visit('$p.side', v.side, depth + 1);
      case BoxDecoration():
        visit('$p.color', v.color, depth + 1);
      case SystemUiOverlayStyle():
        visit('$p.statusBarColor', v.statusBarColor, depth + 1);
        visit(
          '$p.systemNavigationBarColor',
          v.systemNavigationBarColor,
          depth + 1,
        );
      case Diagnosticable():
        for (final prop in v.toDiagnosticsNode().getProperties()) {
          visit('$p.${prop.name}', prop.value, depth + 1);
        }
    }
  }

  visit(path, value, 0);
  return out;
}

void main() {
  test('every color field Flutter reports is one recolor knows about', () {
    final unknown = <String>[];
    for (final p in ThemeData().toDiagnosticsNode().getProperties()) {
      final v = p.value;
      final known = knownColorFields[p.name];
      if (v is! Diagnosticable || known == null) continue;
      for (final q in v.toDiagnosticsNode().getProperties()) {
        final colorish =
            q is ColorProperty || _colorish.hasMatch(q.runtimeType.toString());
        if (colorish && !known.contains(q.name)) {
          unknown.add('${p.name}.${q.name}');
        }
      }
    }
    expect(
      unknown,
      isEmpty,
      reason: 'Flutter added theme color fields. Handle them in recolor.dart.',
    );
  });

  test('recolor reaches every color in every component theme', () {
    sentinels.clear();
    final theme = busyTheme();
    final marked = {for (final c in sentinels) c.toARGB32()};
    expect(marked.length, greaterThan(250), reason: 'fixture looks too small');

    final palettes = resolvePalettes(light: ThemePalette.fromTheme(theme));
    final dark = recolor(theme, from: palettes.light, to: palettes.dark);

    final survivors = [
      for (final (path, color) in collectColors(dark, 'theme'))
        if (marked.contains(color.toARGB32())) path,
    ];
    expect(survivors, isEmpty, reason: 'These kept their light color in dark.');
  });
}
