import 'dart:async';

import 'package:flutter/material.dart';

import 'saved_state.dart';
import 'storage.dart';
import 'theme_mode_state.dart';

/// Holds the user's theme choice and saves it.
///
/// ```dart
/// final theme = ThemeFlowController();
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await theme.load(); // read the saved choice before the first frame
///   runApp(const App());
/// }
/// ```
///
/// It's a plain [ChangeNotifier], so it fits any architecture: register it
/// in get_it, expose it through Provider or Riverpod, or call it from a
/// cubit. Only the choice lives here. Palettes and themes are `ThemeFlow`
/// parameters, so hot reload picks up color changes.
class ThemeFlowController extends ChangeNotifier implements ThemeModeState {
  /// Creates a controller.
  ///
  /// The choice is saved with `shared_preferences` under [storageKey] unless
  /// you pass another [storage], or [ThemeFlowStorage.none] to save nothing.
  /// Use separate keys for separate scopes, such as an app theme and a
  /// reader theme.
  ThemeFlowController({
    ThemeFlowStorage? storage,
    this.storageKey = 'themeflow',
    ThemeMode initialMode = ThemeMode.system,
  }) : _storage = storage ?? SharedPreferencesThemeStorage(),
       _initialMode = initialMode,
       _mode = initialMode;

  /// The key the choice is saved under.
  final String storageKey;

  final ThemeFlowStorage _storage;
  final ThemeMode _initialMode;
  ThemeMode _mode;
  bool _loaded = false;
  bool _chosenBeforeLoad = false;
  Future<void>? _loading;
  _PlatformBrightnessObserver? _observer;

  @override
  ThemeMode get mode => _mode;

  @override
  Brightness get brightness => brightnessFor(_mode, _platformBrightness);

  @override
  bool get isDark => brightness == Brightness.dark;

  @override
  bool get enabled => true;

  /// Whether [load] has finished.
  bool get isLoaded => _loaded;

  Brightness get _platformBrightness =>
      WidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .platformBrightness;

  /// Reads the saved choice. Call it before `runApp` to avoid a flash of the
  /// wrong theme.
  ///
  /// Safe to call more than once. Missing or unreadable data leaves the
  /// initial mode in place, and a choice made while loading wins over the
  /// saved one.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final saved = SavedThemeState.tryParse(await _storage.read(storageKey));
      if (saved != null && !_chosenBeforeLoad && saved.mode != _mode) {
        _mode = saved.mode;
        notifyListeners();
      }
    } catch (error) {
      _debugReport('read the saved theme', error);
    } finally {
      _loaded = true;
    }
  }

  @override
  void setMode(ThemeMode mode) {
    if (!_loaded) _chosenBeforeLoad = true;
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    unawaited(_save());
  }

  @override
  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  @override
  void cycle() => setMode(nextThemeMode(_mode));

  /// Goes back to the initial mode and clears the saved choice.
  ///
  /// With a base theme and the default initial mode, light mode is your
  /// original theme again.
  Future<void> reset() async {
    if (!_loaded) _chosenBeforeLoad = true;
    if (_mode != _initialMode) {
      _mode = _initialMode;
      notifyListeners();
    }
    try {
      await _storage.write(storageKey, null);
    } catch (error) {
      _debugReport('clear the saved theme', error);
    }
  }

  Future<void> _save() async {
    try {
      await _storage.write(storageKey, SavedThemeState(mode: _mode).encode());
    } catch (error) {
      _debugReport('save the theme', error);
    }
  }

  void _debugReport(String action, Object error) {
    assert(() {
      debugPrint('themeflow: could not $action ($error).');
      return true;
    }());
  }

  void _platformBrightnessChanged() {
    if (_mode == ThemeMode.system) notifyListeners();
  }

  // Listen to the platform only while someone listens to us, so a
  // controller that's never attached leaves no observer behind.
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_observer == null) {
      _observer = _PlatformBrightnessObserver(_platformBrightnessChanged);
      WidgetsBinding.instance.addObserver(_observer!);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _detach();
  }

  void _detach() {
    final observer = _observer;
    if (observer != null) WidgetsBinding.instance.removeObserver(observer);
    _observer = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}

class _PlatformBrightnessObserver with WidgetsBindingObserver {
  _PlatformBrightnessObserver(this.onChange);

  final VoidCallback onChange;

  @override
  void didChangePlatformBrightness() => onChange();
}
