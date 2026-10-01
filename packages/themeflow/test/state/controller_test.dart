import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themeflow/src/state/controller.dart';
import 'package:themeflow/src/state/saved_state.dart';
import 'package:themeflow/src/state/storage.dart';

class _FailingStorage implements ThemeFlowStorage {
  @override
  Future<String?> read(String key) async => throw StateError('disk on fire');

  @override
  Future<void> write(String key, String? value) async =>
      throw StateError('disk on fire');
}

class _SlowStorage extends MemoryThemeStorage {
  _SlowStorage(super.values);

  @override
  Future<String?> read(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return super.read(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves and loads the choice', () async {
    final storage = MemoryThemeStorage();
    final a = ThemeFlowController(storage: storage)..setMode(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    expect(storage.values['themeflow'], '{"v":1,"mode":"dark"}');

    final b = ThemeFlowController(storage: storage);
    expect(b.mode, ThemeMode.system);
    await b.load();
    expect(b.mode, ThemeMode.dark);
    expect(b.isLoaded, isTrue);
    a.dispose();
    b.dispose();
  });

  test('reads a bare mode name saved by an app itself', () async {
    final c = ThemeFlowController(
      storage: MemoryThemeStorage({'themeflow': 'light'}),
    );
    await c.load();
    expect(c.mode, ThemeMode.light);
  });

  test('ignores corrupt data and failing storage without throwing', () async {
    final corrupt = ThemeFlowController(
      storage: MemoryThemeStorage({'themeflow': '{not json'}),
      initialMode: ThemeMode.light,
    );
    await corrupt.load();
    expect(corrupt.mode, ThemeMode.light);

    final failing = ThemeFlowController(storage: _FailingStorage());
    await failing.load();
    failing.setMode(ThemeMode.dark);
    await failing.reset();
    expect(failing.mode, ThemeMode.system);
  });

  test('a choice made while loading wins over the saved one', () async {
    final c = ThemeFlowController(
      storage: _SlowStorage({'themeflow': '{"v":1,"mode":"dark"}'}),
    );
    final loading = c.load();
    c.setMode(ThemeMode.light);
    await loading;
    expect(c.mode, ThemeMode.light);
  });

  test('toggle and cycle', () {
    final c = ThemeFlowController(storage: ThemeFlowStorage.none);
    c.setMode(ThemeMode.light);
    c.toggle();
    expect(c.mode, ThemeMode.dark);
    c.toggle();
    expect(c.mode, ThemeMode.light);
    c
      ..setMode(ThemeMode.system)
      ..cycle();
    expect(c.mode, ThemeMode.light);
    c.cycle();
    expect(c.mode, ThemeMode.dark);
    c.cycle();
    expect(c.mode, ThemeMode.system);
  });

  testWidgets('in system mode, toggle flips what is on screen', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final c = ThemeFlowController(storage: ThemeFlowStorage.none);
    expect(c.isDark, isTrue);
    c.toggle();
    expect(c.mode, ThemeMode.light);
  });

  testWidgets('notifies listeners when the platform changes in system mode', (
    tester,
  ) async {
    final c = ThemeFlowController(storage: ThemeFlowStorage.none);
    var calls = 0;
    void listener() => calls++;
    c.addListener(listener);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    expect(calls, 1);
    expect(c.brightness, Brightness.dark);
    c.removeListener(listener);
    c.dispose();
  });

  test('reset goes back to the initial mode and clears storage', () async {
    final storage = MemoryThemeStorage();
    final c = ThemeFlowController(storage: storage)..setMode(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    await c.reset();
    expect(c.mode, ThemeMode.system);
    expect(storage.values, isEmpty);
  });

  test('saved state format', () {
    expect(SavedThemeState.tryParse(null), isNull);
    expect(
      SavedThemeState.tryParse('{"v":9,"mode":"dark"}')?.mode,
      ThemeMode.dark,
    );
    expect(SavedThemeState.tryParse('{"v":1,"mode":"sepia"}'), isNull);
    expect(SavedThemeState.tryParse('[1,2]'), isNull);
  });
}
