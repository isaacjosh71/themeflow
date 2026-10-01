@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/themeflow.dart';

/// A compact kitchen sink: enough components to catch a color regression.
class _KitchenSink extends StatelessWidget {
  const _KitchenSink();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen sink')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              TextButton(onPressed: () {}, child: const Text('Text')),
              FilterChip(
                label: const Text('Chip'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(hintText: 'Hint')),
          Row(
            children: [
              Checkbox(value: true, onChanged: (_) {}),
              Switch(value: true, onChanged: (_) {}),
              Expanded(child: Slider(value: 0.5, onChanged: (_) {})),
            ],
          ),
          const Card(
            child: ListTile(title: Text('Title'), subtitle: Text('Subtitle')),
          ),
          for (final (bg, fg) in [
            (p.successContainer, p.onSuccessContainer),
            (p.warningContainer, p.onWarningContainer),
            (p.errorContainer, p.onErrorContainer),
          ])
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              color: bg,
              child: Text('Status', style: TextStyle(color: fg)),
            ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(value: 0.4),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

ThemeData _legacy() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF00897B),
    foregroundColor: Colors.white,
  ),
  cardTheme: const CardThemeData(color: Color(0xFFF5F5F5), elevation: 0),
);

Future<void> _golden(
  WidgetTester tester,
  String name, {
  ThemePalette? light,
  ThemeData? base,
  DarkStyle style = const DarkStyle(),
  required ThemeMode mode,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ThemeFlow(
      mode: mode,
      light: light,
      base: base,
      darkStyle: style,
      contrastWarnings: false,
      builder: (context, t) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: t.light,
        darkTheme: t.dark,
        themeMode: t.mode,
        home: const _KitchenSink(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));
}

void main() {
  const indigo = ThemePalette(primary: Color(0xFF3D5AFE));

  testWidgets('generated light', (tester) async {
    await _golden(
      tester,
      'generated_light',
      light: indigo,
      mode: ThemeMode.light,
    );
  });

  testWidgets('generated dark', (tester) async {
    await _golden(
      tester,
      'generated_dark',
      light: indigo,
      mode: ThemeMode.dark,
    );
  });

  testWidgets('generated dark, black surfaces', (tester) async {
    await _golden(
      tester,
      'generated_dark_black',
      light: indigo,
      style: const DarkStyle(surfaces: DarkSurfaces.black),
      mode: ThemeMode.dark,
    );
  });

  testWidgets('existing theme recolored to dark', (tester) async {
    await _golden(
      tester,
      'recolored_dark',
      base: _legacy(),
      mode: ThemeMode.dark,
    );
  });
}
