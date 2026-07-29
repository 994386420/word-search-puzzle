import 'package:shared_preferences/shared_preferences.dart';

enum AppearanceMode { system, light, dark }

enum AppSkin { fresh, starry, candy }

class AppearancePreferenceStore {
  const AppearancePreferenceStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const preferenceKey = 'app_appearance_mode';
  static const skinPreferenceKey = 'app_skin';

  final SharedPreferences? _preferences;

  Future<AppearanceMode> getMode() async {
    final prefs = await _getPreferences();
    return modeForCode(prefs.getString(preferenceKey));
  }

  Future<AppSkin> getSkin() async {
    final prefs = await _getPreferences();
    return skinForCode(prefs.getString(skinPreferenceKey));
  }

  Future<void> setMode(AppearanceMode mode) async {
    final prefs = await _getPreferences();
    if (mode == AppearanceMode.light) {
      await prefs.remove(preferenceKey);
      return;
    }
    await prefs.setString(preferenceKey, mode.name);
  }

  Future<void> setSkin(AppSkin skin) async {
    final prefs = await _getPreferences();
    if (skin == AppSkin.fresh) {
      await prefs.remove(skinPreferenceKey);
      return;
    }
    await prefs.setString(skinPreferenceKey, skin.name);
  }

  static AppearanceMode modeForCode(String? code) {
    return switch (code) {
      'system' => AppearanceMode.system,
      'dark' => AppearanceMode.dark,
      _ => AppearanceMode.light,
    };
  }

  static AppSkin skinForCode(String? code) {
    return switch (code) {
      'starry' => AppSkin.starry,
      'candy' => AppSkin.candy,
      _ => AppSkin.fresh,
    };
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }
}
