import 'package:shared_preferences/shared_preferences.dart';

import '../domain/categories.dart';
import '../domain/models.dart';

class DailyChallenge {
  const DailyChallenge({
    required this.dateKey,
    required this.category,
    required this.difficulty,
    required this.seed,
    required this.completedToday,
    required this.streak,
  });

  final String dateKey;
  final WordCategory category;
  final Difficulty difficulty;
  final int seed;
  final bool completedToday;
  final int streak;

  String get progressId => 'daily_$dateKey';

  int get weekday {
    final year = int.parse(dateKey.substring(0, 4));
    final month = int.parse(dateKey.substring(4, 6));
    final day = int.parse(dateKey.substring(6, 8));
    return DateTime(year, month, day).weekday;
  }
}

class DailyChallengeStore {
  const DailyChallengeStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _lastCompletedKey = 'daily_challenge_last_completed';
  static const _streakKey = 'daily_challenge_streak';

  final SharedPreferences? _preferences;

  Future<DailyChallenge> getToday({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final dateKey = _dateKey(today);
    final prefs = await _getPreferences();
    final dayNumber = today.difference(DateTime(2026)).inDays;
    final category = wordCategories[dayNumber.abs() % wordCategories.length];
    final difficulty =
        Difficulty.values[dayNumber.abs() % Difficulty.values.length];
    final seed = _seedFor(dateKey, category.id, difficulty.storageName);
    return DailyChallenge(
      dateKey: dateKey,
      category: category,
      difficulty: difficulty,
      seed: seed,
      completedToday: prefs.getString(_lastCompletedKey) == dateKey,
      streak: prefs.getInt(_streakKey) ?? 0,
    );
  }

  Future<int> markCompleted({DateTime? now}) async {
    final prefs = await _getPreferences();
    final today = _dateOnly(now ?? DateTime.now());
    final dateKey = _dateKey(today);
    final lastCompleted = prefs.getString(_lastCompletedKey);
    if (lastCompleted == dateKey) {
      return prefs.getInt(_streakKey) ?? 1;
    }

    final yesterdayKey = _dateKey(today.subtract(const Duration(days: 1)));
    final currentStreak = prefs.getInt(_streakKey) ?? 0;
    final nextStreak = lastCompleted == yesterdayKey ? currentStreak + 1 : 1;
    await prefs.setString(_lastCompletedKey, dateKey);
    await prefs.setInt(_streakKey, nextStreak);
    return nextStreak;
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}$month$day';
  }

  static int _seedFor(String dateKey, String categoryId, String difficulty) {
    var hash = 17;
    for (final codeUnit in '$dateKey:$categoryId:$difficulty'.codeUnits) {
      hash = 0x1fffffff & (hash * 37 + codeUnit);
    }
    return hash;
  }
}
