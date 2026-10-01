import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:themeflow/themeflow.dart';

/// Every token of the palette on screen, with its contrast checks.
class TokensPage extends StatelessWidget {
  const TokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final failures = palette.contrastReport().failures;
    final groups = <String, List<PaletteToken>>{};
    for (final token in PaletteToken.values) {
      groups.putIfAbsent(token.group, () => []).add(token);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              failures.isEmpty ? Icons.verified_outlined : Icons.info_outline,
              color: failures.isEmpty ? palette.success : palette.warning,
            ),
            title: Text(
              failures.isEmpty
                  ? 'Every pair meets its WCAG contrast minimum'
                  : '${failures.length} pairs fall short',
            ),
            subtitle: failures.isEmpty
                ? null
                : Text(failures.map((f) => '$f').join('\n')),
          ),
        ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              entry.key,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: palette.textSecondary),
            ),
          ),
          for (final token in entry.value) _Swatch(token: token),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.token});

  final PaletteToken token;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = palette[token];
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final alpha = color.a < 1 ? ' at ${(color.a * 100).round()}%' : '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.divider),
        ),
      ),
      title: Text('palette.${token.name}'),
      subtitle: Text('$hex$alpha'),
      trailing: IconButton(
        tooltip: 'Copy',
        icon: const Icon(Icons.copy_outlined, size: 20),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: hex));
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Copied $hex')));
          }
        },
      ),
    );
  }
}
