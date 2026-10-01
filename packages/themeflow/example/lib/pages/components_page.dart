import 'package:flutter/material.dart';
import 'package:themeflow/themeflow.dart';

import '../app_colors.dart';

/// Common Material components, so you can see one theme switch everything.
class ComponentsPage extends StatefulWidget {
  const ComponentsPage({super.key});

  @override
  State<ComponentsPage> createState() => _ComponentsPageState();
}

class _ComponentsPageState extends State<ComponentsPage> {
  bool _checked = true;
  bool _switched = true;
  double _slider = 0.6;
  String _size = 'M';
  final Set<String> _filters = {'Fiction'};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Heading('Buttons'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
            IconButton.filledTonal(
              onPressed: () {},
              icon: const Icon(Icons.favorite_outline),
            ),
          ],
        ),
        const _Heading('Inputs'),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Search books',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
            ),
            Switch(
              value: _switched,
              onChanged: (v) => setState(() => _switched = v),
            ),
            Expanded(
              child: Slider(
                value: _slider,
                onChanged: (v) => setState(() => _slider = v),
              ),
            ),
          ],
        ),
        RadioGroup<String>(
          groupValue: _size,
          onChanged: (v) => setState(() => _size = v ?? _size),
          child: const Row(
            children: [
              Radio<String>(value: 'S'),
              Text('S'),
              Radio<String>(value: 'M'),
              Text('M'),
              Radio<String>(value: 'L'),
              Text('L'),
            ],
          ),
        ),
        const _Heading('Chips'),
        Wrap(
          spacing: 8,
          children: [
            for (final genre in const ['Fiction', 'History', 'Science'])
              FilterChip(
                label: Text(genre),
                selected: _filters.contains(genre),
                onSelected: (on) => setState(
                  () => on ? _filters.add(genre) : _filters.remove(genre),
                ),
              ),
          ],
        ),
        const _Heading('Cards and lists'),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: CircleAvatar(child: Text('A')),
                title: Text('Things Fall Apart'),
                subtitle: Text('Chinua Achebe'),
                trailing: Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.star, color: AppColors.gold.of(context)),
                title: const Text('Your own color token'),
                subtitle: const Text('AppColors.gold.of(context)'),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.page.of(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'A reading surface with its own colors, given explicitly for dark.',
            style: TextStyle(color: AppColors.ink.of(context)),
          ),
        ),
        const _Heading('Status'),
        _Banner(
          icon: Icons.check_circle_outline,
          text: 'Saved to your library',
          background: palette.successContainer,
          foreground: palette.onSuccessContainer,
        ),
        _Banner(
          icon: Icons.warning_amber_outlined,
          text: 'You are offline',
          background: palette.warningContainer,
          foreground: palette.onWarningContainer,
        ),
        _Banner(
          icon: Icons.error_outline,
          text: 'Payment failed',
          background: palette.errorContainer,
          foreground: palette.onErrorContainer,
        ),
        const _Heading('Progress and loading'),
        const LinearProgressIndicator(value: 0.4),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: palette.skeleton,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const _Heading('Overlays'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Added to your shelf'),
                  action: SnackBarAction(label: 'Undo', onPressed: () {}),
                ),
              ),
              child: const Text('Snackbar'),
            ),
            OutlinedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete highlight?'),
                  content: const Text('This removes it from all your devices.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
              child: const Text('Dialog'),
            ),
            OutlinedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text('Switch from inside a sheet'),
                          subtitle: Text('The sheet updates while it is open.'),
                        ),
                        ThemeModeSwitchTile(),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Bottom sheet'),
            ),
          ],
        ),
        const _Heading('Always dark'),
        ForceBrightness.dark(
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('A video player stays dark'),
              subtitle: Text(
                context.pick(
                  light: 'The app is light right now',
                  dark: 'The app is dark right now',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: context.palette.textSecondary),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: foreground),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: foreground)),
      ],
    ),
  );
}
