import 'package:flutter/material.dart';
import 'package:themeflow/themeflow.dart';

import 'app_theme.dart';
import 'demo_settings.dart';
import 'pages/components_page.dart';
import 'pages/settings_page.dart';
import 'pages/tokens_page.dart';

/// Remembers the user's choice with shared_preferences.
final theme = ThemeFlowController();

final demo = DemoSettings();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await theme.load(); // read the saved choice before the first frame
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) => ThemeFlow(
        controller: theme,
        // The one line an existing app adds: its own light theme as base.
        base: demo.fromExistingTheme ? AppTheme.light(demo.brand) : null,
        // A new app gives a palette instead. Dark is derived either way.
        light: demo.fromExistingTheme
            ? null
            : ThemePalette(primary: demo.brand),
        darkStyle: DarkStyle(surfaces: demo.surfaces),
        builder: (context, t) => MaterialApp(
          title: 'themeflow',
          debugShowCheckedModeBanner: false,
          theme: t.light,
          darkTheme: t.dark,
          themeMode: t.mode,
          home: const HomePage(),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  static const _titles = ['Components', 'Tokens', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: const [ThemeModeButton(), SizedBox(width: 8)],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [ComponentsPage(), TokensPage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            label: 'Components',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            label: 'Tokens',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
