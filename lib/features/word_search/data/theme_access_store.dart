import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ThemeAccessStore {
  const ThemeAccessStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _dailyUnlocksKey = 'theme_daily_unlocks_v1';
  static const _familyAccessKey = 'family_access_v1';

  final SharedPreferences? _preferences;

  Future<bool> hasFamilyAccess() async {
    final prefs = await _getPreferences();
    return prefs.getBool(_familyAccessKey) ?? false;
  }

  Future<void> setFamilyAccess(bool enabled) async {
    final prefs = await _getPreferences();
    await prefs.setBool(_familyAccessKey, enabled);
  }

  Future<Set<String>> dailyUnlockedThemeIds({DateTime? now}) async {
    final prefs = await _getPreferences();
    final raw = prefs.getString(_dailyUnlocksKey);
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['date']?.toString() != _dateKey(now ?? DateTime.now())) {
        return <String>{};
      }
      return (decoded['themes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> unlockForToday(String themeId, {DateTime? now}) async {
    final prefs = await _getPreferences();
    final unlocks = await dailyUnlockedThemeIds(now: now)
      ..add(themeId);
    await prefs.setString(
      _dailyUnlocksKey,
      jsonEncode({
        'date': _dateKey(now ?? DateTime.now()),
        'themes': unlocks.toList(growable: false)..sort(),
      }),
    );
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}$month$day';
  }
}
