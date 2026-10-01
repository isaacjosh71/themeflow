import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/themeflow.dart';

const brand = Color(0xFF3D5AFE);
const gold = ColorToken(0xFFC9A227, id: 'gold');

late BuildContext probe;

Widget _probe() => Builder(
  builder: (context) {
    probe = context;
    return Container(color: context.palette.surface);
  },
);

ThemeFlowController memoryController([ThemeMode mode = ThemeMode.light]) =>
    ThemeFlowController(storage: MemoryThemeStorage(), initialMode: mode);

Widget app({
  ThemeFlowController? controller,
  ThemeMode? mode,
  ValueChanged<ThemeMode>? onModeChanged,
  ThemePalette? light = const ThemePalette(primary: brand),
  ThemePalette? dark,
  ThemeData? base,
  bool enabled = true,
  bool deferFirstFrame = false,
  bool contrastWarnings = false,
  ThemeFlowLabels labels = const ThemeFlowLabels(),
  void Function(ThemeFlowThemes t)? onBuild,
  Widget? home,
}) => ThemeFlow(
  controller: controller,
  mode: mode,
  onModeChanged: onModeChanged,
  light: light,
  dark: dark,
  base: base,
  enabled: enabled,
  deferFirstFrame: deferFirstFrame,
  contrastWarnings: contrastWarnings,
  labels: labels,
  builder: (context, t) {
    onBuild?.call(t);
    return MaterialApp(
      theme: t.light,
      darkTheme: t.dark,
      themeMode: t.mode,
      home: Scaffold(body: home ?? _probe()),
    );
  },
);

void main() {
  testWidgets('switches the whole app between light and dark', (tester) async {
    final c = memoryController();
    await tester.pumpWidget(app(controller: c));
    expect(probe.isDark, isFalse);
    expect(probe.palette.brightness, Brightness.light);

    c.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(probe.isDark, isTrue);
    expect(Theme.of(probe).brightness, Brightness.dark);
    expect(
      tester.widget<Container>(find.byType(Container).last).color,
      probe.palette.surface,
    );
  });

  testWidgets('system mode follows the device', (tester) async {
    final c = memoryController(ThemeMode.system);
    await tester.pumpWidget(app(controller: c));
    expect(probe.isDark, isFalse);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(probe.isDark, isTrue);
  });

  testWidgets('with a base theme, light mode is that theme', (tester) async {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      cardTheme: const CardThemeData(color: Colors.white, elevation: 3),
    );
    late ThemeFlowThemes t;
    await tester.pumpWidget(
      app(
        controller: memoryController(),
        light: null,
        base: base,
        onBuild: (x) => t = x,
      ),
    );
    expect(t.light.copyWith(extensions: base.extensions.values), base);
    expect(t.dark.brightness, Brightness.dark);
    expect(t.dark.cardTheme.elevation, 3);
  });

  testWidgets('rebuilding with the same config reuses the themes', (
    tester,
  ) async {
    final themes = <ThemeFlowThemes>[];
    final c = memoryController();
    await tester.pumpWidget(app(controller: c, onBuild: themes.add));
    await tester.pumpWidget(app(controller: c, onBuild: themes.add));
    expect(identical(themes.first.light, themes.last.light), isTrue);
  });

  testWidgets('a new palette takes effect at once (hot reload)', (
    tester,
  ) async {
    final c = memoryController();
    await tester.pumpWidget(app(controller: c));
    expect(Theme.of(probe).colorScheme.primary, brand);
    await tester.pumpWidget(
      app(
        controller: c,
        light: const ThemePalette(primary: Color(0xFF00897B)),
      ),
    );
    await tester.pumpAndSettle();
    expect(Theme.of(probe).colorScheme.primary, const Color(0xFF00897B));
  });

  testWidgets('controlled mode uses your state', (tester) async {
    ThemeMode? asked;
    await tester.pumpWidget(
      app(
        mode: ThemeMode.dark,
        onModeChanged: (m) => asked = m,
        home: const ThemeModeSwitch(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    expect(asked, ThemeMode.light);
  });

  testWidgets('enabled: false shows light and hides the toggles', (
    tester,
  ) async {
    final c = memoryController(ThemeMode.dark);
    await tester.pumpWidget(
      app(
        controller: c,
        enabled: false,
        home: Column(children: [_probe(), const ThemeModeSwitch()]),
      ),
    );
    expect(probe.isDark, isFalse);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('loads the saved choice itself', (tester) async {
    final c = ThemeFlowController(
      storage: MemoryThemeStorage({'themeflow': '{"v":1,"mode":"dark"}'}),
    );
    await tester.pumpWidget(app(controller: c));
    await tester.pumpAndSettle();
    expect(c.isLoaded, isTrue);
    expect(probe.isDark, isTrue);
  });

  testWidgets('styles the system bars to match', (tester) async {
    final c = memoryController();
    await tester.pumpWidget(app(controller: c));
    SystemUiOverlayStyle style() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        )
        .value;
    expect(style().statusBarIconBrightness, Brightness.dark);
    c.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(style().statusBarIconBrightness, Brightness.light);
    expect(style().systemNavigationBarColor, probe.palette.background);
  });

  testWidgets('an open dialog updates when the mode changes', (tester) async {
    final c = memoryController();
    await tester.pumpWidget(app(controller: c));
    unawaited(
      showDialog<void>(
        context: probe,
        builder: (context) => Builder(
          builder: (context) => Container(
            key: const Key('dialog'),
            color: context.palette.surfaceElevated,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    c.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final color = tester
        .widget<Container>(find.byKey(const Key('dialog')))
        .color;
    final dark = resolvePalettes(
      light: const ThemePalette(primary: brand),
    ).dark;
    expect(color, dark.surfaceElevated);
  });

  testWidgets('tokens, pick and ColorToken follow the theme', (tester) async {
    final c = memoryController();
    await tester.pumpWidget(app(controller: c));
    expect(probe.pick(light: 'sun', dark: 'moon'), 'sun');
    expect(gold.of(probe), gold.light);
    c.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(probe.pick(light: 'sun', dark: 'moon'), 'moon');
    expect(gold.of(probe), probe.palette.resolve(gold));
    expect(gold.of(probe), isNot(gold.light));
  });

  testWidgets('ForceBrightness shows a subtree in the other theme', (
    tester,
  ) async {
    late BuildContext inside;
    await tester.pumpWidget(
      app(
        controller: memoryController(),
        home: ForceBrightness.dark(
          child: Builder(
            builder: (context) {
              inside = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(inside.isDark, isTrue);
    expect(Theme.of(inside).brightness, Brightness.dark);
    expect(
      DefaultTextStyle.of(inside).style.color,
      Theme.of(inside).textTheme.bodyMedium!.color,
    );
  });

  testWidgets('PaletteOverride changes tokens and Material widgets below', (
    tester,
  ) async {
    const cream = Color(0xFFFFF8E1);
    late BuildContext inside;
    await tester.pumpWidget(
      app(
        controller: memoryController(),
        home: PaletteOverride(
          colors: {gold: Colors.amber},
          update: (p) => p.copyWith(surface: cream),
          child: Builder(
            builder: (context) {
              inside = context;
              return const Card(child: SizedBox(width: 10, height: 10));
            },
          ),
        ),
      ),
    );
    expect(inside.palette.surface, cream);
    expect(gold.of(inside), Colors.amber);
    expect(Theme.of(inside).cardTheme.color, cream);
  });

  testWidgets('ThemedImage swaps images with the mode', (tester) async {
    final c = memoryController();
    final light = MemoryImage(Uint8List.fromList(_pixel));
    final darkImage = MemoryImage(Uint8List.fromList(_pixel));
    await tester.pumpWidget(
      app(
        controller: c,
        home: Column(
          children: [
            ThemedImage(light: light, dark: darkImage),
            ThemedImage.dimmed(image: light),
          ],
        ),
      ),
    );
    Image image(int i) => tester.widget<Image>(find.byType(Image).at(i));
    expect(image(0).image, light);
    expect(image(1).color, isNull);
    c.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(image(0).image, darkImage);
    expect(image(1).color, isNotNull);
  });

  testWidgets('prints a warning for hard-to-read colors you set', (
    tester,
  ) async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.pumpWidget(
        app(
          controller: memoryController(),
          light: const ThemePalette(primary: Color(0xFFFFEB3B)),
          contrastWarnings: true,
        ),
      );
    } finally {
      debugPrint = original;
    }
    expect(logs.join('\n'), contains('primary on background'));
  });
}

// A 1x1 transparent PNG.
const _pixel = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
