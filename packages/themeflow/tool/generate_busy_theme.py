#!/usr/bin/env python3
"""Generates test/theme/busy_theme.dart: a ThemeData with a unique sentinel
color in every color field of every component theme.

The recolor exhaustiveness test recolors it and checks no sentinel survives.
Run it again when Flutter adds theme fields:

    python3 tool/generate_busy_theme.py [path/to/flutter]
"""
import glob, os, re, shutil, subprocess, sys

flutter = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
    os.path.dirname(os.path.realpath(shutil.which('flutter'))))
SRC = os.path.join(flutter, 'packages/flutter/lib/src/material')
OUT = os.path.join(os.path.dirname(__file__), '..', 'test/theme/busy_theme.dart')
def _version():
    import json
    meta = os.path.join(flutter, 'bin/cache/flutter.version.json')
    if os.path.exists(meta):
        return json.load(open(meta)).get('frameworkVersion', 'unknown')
    legacy = os.path.join(flutter, 'version')
    return open(legacy).read().strip() if os.path.exists(legacy) else 'unknown'

version = _version()

text = {f: open(f).read() for f in glob.glob(SRC + '/*.dart')}

def params(name):
    pat = re.compile(r'^class ' + re.escape(name) + r'\b[^{]*\{', re.M)
    for t in text.values():
        m = pat.search(t)
        if not m:
            continue
        depth, i = 1, m.end()
        while depth:
            depth += {'{': 1, '}': -1}.get(t[i], 0)
            i += 1
        body = t[m.end():i]
        c = re.search(r'\b' + re.escape(name) + r'\s+copyWith\(\{(.*?)\}\)', body, re.S)
        if not c:
            return []
        out = []
        for chunk in re.sub(r'@Deprecated\((?:[^()]|\([^()]*\))*\)', '', c.group(1)).split(','):
            chunk = ' '.join(l.split('//')[0] for l in chunk.split('\n')).strip()
            if chunk:
                typ, field = chunk.rsplit(' ', 1)
                out.append((typ.strip(), field.strip()))
        return out
    raise SystemExit(f'class {name} not found')

# Fields themeflow leaves alone on purpose: shadows and barriers keep their
# meaning, deprecated fields are skipped, and dayPeriodButtonStyle has no
# getter.
SKIP = re.compile(r'shadow|scrim|barrier', re.I)
SKIP_FIELDS = {('AppBarThemeData', 'color'), ('TimePickerThemeData', 'dayPeriodButtonStyle')}

def value(typ, owner):
    t = typ.rstrip('?')
    return {
        'Color': 's()',
        'WidgetStateProperty<Color?>': 'WidgetStatePropertyAll<Color?>(s())',
        'TextStyle': 'TextStyle(color: s())',
        'WidgetStateProperty<TextStyle?>': 'WidgetStatePropertyAll<TextStyle?>(TextStyle(color: s()))',
        'BorderSide': 'BorderSide(color: s())',
        'WidgetStateProperty<BorderSide?>': 'WidgetStatePropertyAll<BorderSide?>(BorderSide(color: s()))',
        'IconThemeData': 'IconThemeData(color: s())',
        'WidgetStateProperty<IconThemeData?>': 'WidgetStatePropertyAll<IconThemeData?>(IconThemeData(color: s()))',
        'ShapeBorder': 'RoundedRectangleBorder(side: BorderSide(color: s()))',
        'OutlinedBorder': 'RoundedRectangleBorder(side: BorderSide(color: s()))',
        'WidgetStateProperty<OutlinedBorder?>': 'WidgetStatePropertyAll<OutlinedBorder?>(RoundedRectangleBorder(side: BorderSide(color: s())))',
        'InputBorder': 'OutlineInputBorder(borderSide: BorderSide(color: s()))',
        'Decoration': 'BoxDecoration(color: s())',
        'ButtonStyle': 'busyButtonStyle()',
        'MenuStyle': 'busyMenuStyle()',
        'SystemUiOverlayStyle': 'SystemUiOverlayStyle(statusBarColor: s(), systemNavigationBarColor: s())',
        'InputDecorationTheme': 'InputDecorationTheme(data: busyInput())',
        'Object': 'busyInput()',  # inputDecorationTheme on DropdownMenuThemeData
    }.get(t)

def busy(cls, var_type=None):
    lines = []
    for typ, field in params(cls):
        if (cls, field) in SKIP_FIELDS or SKIP.search(field):
            continue
        if field == 'inputDecorationTheme' and typ.startswith('Object'):
            v = 'busyInput()'
        else:
            v = value(typ, cls)
        if v:
            lines.append(f'    {field}: {v},')
    return lines

THEMES = [
    ('appBarTheme', 'AppBarThemeData'), ('badgeTheme', 'BadgeThemeData'),
    ('bannerTheme', 'MaterialBannerThemeData'), ('bottomAppBarTheme', 'BottomAppBarThemeData'),
    ('bottomNavigationBarTheme', 'BottomNavigationBarThemeData'), ('bottomSheetTheme', 'BottomSheetThemeData'),
    ('cardTheme', 'CardThemeData'), ('carouselViewTheme', 'CarouselViewThemeData'),
    ('checkboxTheme', 'CheckboxThemeData'), ('chipTheme', 'ChipThemeData'),
    ('dataTableTheme', 'DataTableThemeData'), ('datePickerTheme', 'DatePickerThemeData'),
    ('dialogTheme', 'DialogThemeData'), ('dividerTheme', 'DividerThemeData'),
    ('drawerTheme', 'DrawerThemeData'), ('dropdownMenuTheme', 'DropdownMenuThemeData'),
    ('expansionTileTheme', 'ExpansionTileThemeData'), ('floatingActionButtonTheme', 'FloatingActionButtonThemeData'),
    ('listTileTheme', 'ListTileThemeData'), ('navigationBarTheme', 'NavigationBarThemeData'),
    ('navigationDrawerTheme', 'NavigationDrawerThemeData'), ('navigationRailTheme', 'NavigationRailThemeData'),
    ('popupMenuTheme', 'PopupMenuThemeData'), ('progressIndicatorTheme', 'ProgressIndicatorThemeData'),
    ('radioTheme', 'RadioThemeData'), ('scrollbarTheme', 'ScrollbarThemeData'),
    ('searchBarTheme', 'SearchBarThemeData'), ('searchViewTheme', 'SearchViewThemeData'),
    ('sliderTheme', 'SliderThemeData'), ('snackBarTheme', 'SnackBarThemeData'),
    ('switchTheme', 'SwitchThemeData'), ('tabBarTheme', 'TabBarThemeData'),
    ('textSelectionTheme', 'TextSelectionThemeData'), ('timePickerTheme', 'TimePickerThemeData'),
    ('toggleButtonsTheme', 'ToggleButtonsThemeData'), ('tooltipTheme', 'TooltipThemeData'),
]
STYLE_ONLY = ['elevatedButtonTheme:ElevatedButtonThemeData', 'filledButtonTheme:FilledButtonThemeData',
              'iconButtonTheme:IconButtonThemeData', 'menuButtonTheme:MenuButtonThemeData',
              'outlinedButtonTheme:OutlinedButtonThemeData', 'textButtonTheme:TextButtonThemeData',
              'segmentedButtonTheme:SegmentedButtonThemeData']

out = [
    '// GENERATED by tool/generate_busy_theme.py from Flutter ' + version.split()[0] + '. Do not edit.',
    '//',
    '// A ThemeData with a unique sentinel color in every color field of every',
    '// component theme, for the recolor exhaustiveness test.',
    '',
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/services.dart';",
    '',
    'final List<Color> sentinels = [];',
    '',
    '/// A new sentinel: a mid-tone color no mapping would leave unchanged.',
    'Color s() {',
    '  final i = sentinels.length;',
    '  final c = HSLColor.fromAHSL(1, (i * 37) % 360, 0.6, 0.5).toColor();',
    '  sentinels.add(c);',
    '  return c;',
    '}',
    '',
    'ButtonStyle busyButtonStyle() => ButtonStyle(',
    *busy('ButtonStyle'),
    ');',
    '',
    'MenuStyle busyMenuStyle() => MenuStyle(',
    *busy('MenuStyle'),
    ');',
    '',
    'InputDecorationThemeData busyInput() => InputDecorationThemeData(',
    *busy('InputDecorationThemeData'),
    ');',
    '',
    'ThemeData busyTheme() => ThemeData(',
    '  scaffoldBackgroundColor: s(),',
    '  canvasColor: s(),',
    '  cardColor: s(),',
    '  dividerColor: s(),',
    '  hintColor: s(),',
    '  disabledColor: s(),',
    '  unselectedWidgetColor: s(),',
    '  textTheme: TextTheme(bodyLarge: TextStyle(color: s()), titleLarge: TextStyle(color: s())),',
    '  iconTheme: IconThemeData(color: s()),',
    '  inputDecorationTheme: busyInput(),',
]
for field, cls in THEMES:
    out.append(f'  {field}: {cls}(')
    out.extend('  ' + l for l in busy(cls))
    out.append('  ),')
for item in STYLE_ONLY:
    field, cls = item.split(':')
    out.append(f'  {field}: {cls}(style: busyButtonStyle()),')
out.append('  menuTheme: MenuThemeData(style: busyMenuStyle()),')
out.append('  menuBarTheme: MenuBarThemeData(style: busyMenuStyle()),')
out.append(');')
open(OUT, 'w').write('\n'.join(out) + '\n')
print('wrote', os.path.relpath(OUT))
