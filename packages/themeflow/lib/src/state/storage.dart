import 'package:shared_preferences/shared_preferences.dart';

/// Where the user's theme choice is saved.
///
/// Two methods, so any store works: Hive, secure storage, HydratedBloc, a
/// server. Errors are caught by the controller and never reach your app.
abstract interface class ThemeFlowStorage {
  /// Saves nothing. Use it when you keep the mode in your own state.
  static const ThemeFlowStorage none = _NoStorage();

  /// Returns the value saved under [key], or null.
  Future<String?> read(String key);

  /// Saves [value] under [key]. A null [value] deletes it.
  Future<void> write(String key, String? value);
}

class _NoStorage implements ThemeFlowStorage {
  const _NoStorage();

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String? value) async {}
}

/// Keeps values in memory, for tests.
class MemoryThemeStorage implements ThemeFlowStorage {
  /// Creates a store, optionally with [values] already in it.
  MemoryThemeStorage([Map<String, String>? values]) : values = values ?? {};

  /// What's stored, by key.
  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Saves with `shared_preferences`. This is the default.
class SharedPreferencesThemeStorage implements ThemeFlowStorage {
  /// Creates a store backed by [preferences], or by a new
  /// `SharedPreferencesAsync` when null.
  SharedPreferencesThemeStorage([SharedPreferencesAsync? preferences])
    : _given = preferences;

  final SharedPreferencesAsync? _given;

  // Created on first use, so building a controller before
  // `WidgetsFlutterBinding.ensureInitialized()` is safe.
  late final SharedPreferencesAsync _preferences =
      _given ?? SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _preferences.remove(key)
      : _preferences.setString(key, value);
}
