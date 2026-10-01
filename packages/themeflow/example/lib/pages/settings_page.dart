import 'package:flutter/material.dart';
import 'package:themeflow/themeflow.dart';

import '../main.dart' show demo, theme;

/// Every ready-made toggle, plus the demo's own knobs.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _brands = [
    Color(0xFF3D5AFE),
    Color(0xFF00897B),
    Color(0xFFE65100),
    Color(0xFFC2185B),
    Color(0xFF6D4C41),
    Color(0xFF111111),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _Section('Appearance (ThemeModeRadios)'),
          const ThemeModeRadios(),
          const _Section('ThemeModeSegmented'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ThemeModeSegmented(),
          ),
          const _Section('ThemeModeSwitchTile'),
          const ThemeModeSwitchTile(secondary: Icon(Icons.dark_mode_outlined)),
          const ListTile(
            title: Text('ThemeModeMenu'),
            trailing: ThemeModeMenu(),
          ),
          const _Section('Demo'),
          SwitchListTile(
            title: const Text('Start from an existing theme'),
            subtitle: Text(
              demo.fromExistingTheme
                  ? 'Recoloring AppTheme.light: fonts and shapes kept'
                  : 'Generating a theme from the brand color',
            ),
            value: demo.fromExistingTheme,
            onChanged: (v) => demo.fromExistingTheme = v,
          ),
          ListTile(
            title: const Text('Brand color'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 10,
                children: [
                  for (final color in _brands)
                    _BrandDot(
                      color: color,
                      selected: color == demo.brand,
                      ring: palette.text,
                      onTap: () => demo.brand = color,
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            title: const Text('Dark surfaces'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<DarkSurfaces>(
                showSelectedIcon: false,
                selected: {demo.surfaces},
                onSelectionChanged: (s) => demo.surfaces = s.first,
                segments: const [
                  ButtonSegment(
                    value: DarkSurfaces.tinted,
                    label: Text('Tinted'),
                  ),
                  ButtonSegment(
                    value: DarkSurfaces.neutral,
                    label: Text('Neutral'),
                  ),
                  ButtonSegment(
                    value: DarkSurfaces.black,
                    label: Text('Black'),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset to the original light theme'),
            onTap: theme.reset,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: context.palette.textSecondary),
    ),
  );
}

class _BrandDot extends StatelessWidget {
  const _BrandDot({
    required this.color,
    required this.selected,
    required this.ring,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Brand color',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? ring : context.palette.divider,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    ),
  );
}
