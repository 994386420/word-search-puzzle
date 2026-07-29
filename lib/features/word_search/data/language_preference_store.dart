import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class LanguagePreferenceStore {
  const LanguagePreferenceStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const preferenceKey = 'app_language_code';
  static const supportedLanguageCodes = ['en', 'zh', 'ko'];

  final SharedPreferences? _preferences;

  Future<Locale?> getLocale() async {
    final prefs = await _getPreferences();
    return localeForCode(prefs.getString(preferenceKey));
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = await _getPreferences();
    final languageCode = locale?.languageCode;
    if (languageCode == null ||
        !supportedLanguageCodes.contains(languageCode)) {
      await prefs.remove(preferenceKey);
      return;
    }
    await prefs.setString(preferenceKey, languageCode);
  }

  static Locale? localeForCode(String? languageCode) {
    return switch (languageCode) {
      'en' => const Locale('en'),
      'zh' => const Locale('zh'),
      'ko' => const Locale('ko'),
      _ => null,
    };
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }
}
