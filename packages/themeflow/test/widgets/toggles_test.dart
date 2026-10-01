import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/themeflow.dart';

Future<ThemeFlowController> pumpToggle(
  WidgetTester tester,
  Widget toggle, {
  ThemeMode mode = ThemeMode.light,
  ThemeFlowLabels labels = const ThemeFlowLabels(),
}) async {
  final c = ThemeFlowController(
    storage: MemoryThemeStorage(),
    initialMode: mode,
  );
  await tester.pumpWidget(
    ThemeFlow(
      controller: c,
      light: const ThemePalette(primary: Color(0xFF3D5AFE)),
      labels: labels,
      contrastWarnings: false,
      builder: (context, t) => MaterialApp(
        theme: t.light,
        darkTheme: t.dark,
        themeMode: t.mode,
        home: Scaffold(body: Center(child: toggle)),
      ),
    ),
  );
  return c;
}

void main() {
  testWidgets('ThemeModeSwitch turns dark on and off', (tester) async {
    final c = await pumpToggle(tester, const ThemeModeSwitch(adaptive: false));
    await tester.tap(find.byType(Switch));
    expect(c.mode, ThemeMode.dark);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    expect(c.mode, ThemeMode.light);
    expect(find.bySemanticsLabel('Dark mode'), findsOneWidget);
  });

  testWidgets('ThemeModeSwitch shows what is on screen in system mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final c = await pumpToggle(
      tester,
      const ThemeModeSwitch(adaptive: false),
      mode: ThemeMode.system,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    expect(c.mode, ThemeMode.light);
  });

  testWidgets('ThemeModeSwitchTile', (tester) async {
    final c = await pumpToggle(
      tester,
      const ThemeModeSwitchTile(adaptive: false),
    );
    await tester.tap(find.text('Dark mode'));
    expect(c.mode, ThemeMode.dark);
  });

  testWidgets('ThemeModeButton toggles, or cycles', (tester) async {
    final c = await pumpToggle(tester, const ThemeModeButton());
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(c.mode, ThemeMode.dark);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    final cycling = await pumpToggle(
      tester,
      const ThemeModeButton(cycle: true),
      mode: ThemeMode.system,
    );
    expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(cycling.mode, ThemeMode.light);
  });

  testWidgets('ThemeModeSegmented', (tester) async {
    final c = await pumpToggle(tester, const ThemeModeSegmented());
    await tester.tap(find.text('Dark'));
    expect(c.mode, ThemeMode.dark);
    await tester.pumpAndSettle();
    await tester.tap(find.text('System'));
    expect(c.mode, ThemeMode.system);
  });

  testWidgets('ThemeModeRadios', (tester) async {
    final c = await pumpToggle(tester, const ThemeModeRadios());
    expect(find.text('Follows your device settings'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    expect(c.mode, ThemeMode.dark);
  });

  testWidgets('ThemeModeMenu', (tester) async {
    final c = await pumpToggle(tester, const ThemeModeMenu());
    await tester.tap(find.byType(PopupMenuButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(c.mode, ThemeMode.dark);
  });

  testWidgets('ThemeModeBuilder wraps any control', (tester) async {
    final c = await pumpToggle(
      tester,
      ThemeModeBuilder(
        builder: (context, s) => TextButton(
          onPressed: s.toggle,
          child: Text(s.isDark ? 'Moon' : 'Sun'),
        ),
      ),
    );
    await tester.tap(find.text('Sun'));
    await tester.pumpAndSettle();
    expect(c.mode, ThemeMode.dark);
    expect(find.text('Moon'), findsOneWidget);
  });

  testWidgets('labels can be translated', (tester) async {
    await pumpToggle(
      tester,
      const ThemeModeSegmented(),
      labels: const ThemeFlowLabels(
        system: 'Système',
        light: 'Clair',
        dark: 'Sombre',
      ),
    );
    expect(find.text('Sombre'), findsOneWidget);
  });

  testWidgets('context.themeFlow changes the mode from code', (tester) async {
    late BuildContext context;
    final c = await pumpToggle(
      tester,
      Builder(
        builder: (ctx) {
          context = ctx;
          return const SizedBox();
        },
      ),
    );
    context.themeFlow.setMode(ThemeMode.dark);
    expect(c.mode, ThemeMode.dark);
  });
}
