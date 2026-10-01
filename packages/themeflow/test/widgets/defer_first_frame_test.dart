import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/themeflow.dart';

class _SlowStorage extends MemoryThemeStorage {
  _SlowStorage(this.delay) : super({'themeflow': '{"v":1,"mode":"dark"}'});

  final Duration delay;

  @override
  Future<String?> read(String key) async {
    await Future<void>.delayed(delay);
    return super.read(key);
  }
}

Widget _app(ThemeFlowController c) => ThemeFlow(
  controller: c,
  deferFirstFrame: true,
  light: const ThemePalette(primary: Color(0xFF3D5AFE)),
  contrastWarnings: false,
  builder: (context, t) => MaterialApp(
    theme: t.light,
    darkTheme: t.dark,
    themeMode: t.mode,
    home: const SizedBox(),
  ),
);

void main() {
  testWidgets('holds the first frame until the saved choice is read', (
    tester,
  ) async {
    final c = ThemeFlowController(
      storage: _SlowStorage(const Duration(milliseconds: 50)),
    );
    await tester.pumpWidget(_app(c));
    expect(tester.binding.sendFramesToEngine, isFalse);
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(c.mode, ThemeMode.dark);
  });

  testWidgets('gives up after 500 ms', (tester) async {
    final c = ThemeFlowController(
      storage: _SlowStorage(const Duration(seconds: 3)),
    );
    await tester.pumpWidget(_app(c));
    expect(tester.binding.sendFramesToEngine, isFalse);
    await tester.pump(const Duration(milliseconds: 510));
    expect(tester.binding.sendFramesToEngine, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });
}
