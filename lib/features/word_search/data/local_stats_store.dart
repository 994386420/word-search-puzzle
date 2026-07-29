import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/categories.dart';
import '../domain/models.dart';

class LocalStats {
  const LocalStats({
    required this.totalWordsFound,
    required this.gamesCompleted,
    required this.dailyCompleted,
    required this.totalStars,
    required this.unlockedBadgeIds,
    required this.categoryCompletions,
    this.bestClassicSeconds,
    this.bestSpeedScore,
  });

  final int totalWordsFound;
  final int gamesCompleted;
  final int dailyCompleted;
  final int totalStars;
  final Set<String> unlockedBadgeIds;
  final int? bestClassicSeconds;
  final int? bestSpeedScore;
  final Map<String, int> categoryCompletions;

  WordCategory? get favoriteCategory {
    if (categoryCompletions.isEmpty) {
      return null;
    }
    final favoriteId = categoryCompletions.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    for (final category in wordCategories) {
      if (category.id == favoriteId) {
        return category;
      }
    }
    return null;
  }
}

class LocalStatsStore {
  const LocalStatsStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _totalWordsFoundKey = 'local_stats_total_words_found';
  static const _gamesCompletedKey = 'local_stats_games_completed';
  static const _dailyCompletedKey = 'local_stats_daily_completed';
  static const _bestClassicSecondsKey = 'local_stats_best_classic_seconds';
  static const _bestSpeedScoreKey = 'local_stats_best_speed_score';
  static const _categoryCompletionsKey = 'local_stats_category_completions';
  static const _totalStarsKey = 'local_stats_total_stars';
  static const _unlockedBadgesKey = 'local_stats_unlocked_badges';

  final SharedPreferences? _preferences;

  Future<LocalStats> getStats() async {
    final prefs = await _getPreferences();
    return LocalStats(
      totalWordsFound: prefs.getInt(_totalWordsFoundKey) ?? 0,
      gamesCompleted: prefs.getInt(_gamesCompletedKey) ?? 0,
      dailyCompleted: prefs.getInt(_dailyCompletedKey) ?? 0,
      totalStars: prefs.getInt(_totalStarsKey) ?? 0,
      unlockedBadgeIds: _decodeStringSet(prefs.getString(_unlockedBadgesKey)),
      bestClassicSeconds: prefs.getInt(_bestClassicSecondsKey),
      bestSpeedScore: prefs.getInt(_bestSpeedScoreKey),
      categoryCompletions: _decodeCounterMap(
        prefs.getString(_categoryCompletionsKey),
      ),
    );
  }

  Future<void> recordWordFound({required WordCategory category}) async {
    final prefs = await _getPreferences();
    await prefs.setInt(
      _totalWordsFoundKey,
      (prefs.getInt(_totalWordsFoundKey) ?? 0) + 1,
    );
  }

  Future<LocalRewardResult> recordGameCompleted({
    required WordCategory category,
    required GameMode mode,
    required int elapsed,
    required int score,
    required bool isDailyChallenge,
    int stars = 0,
  }) async {
    final prefs = await _getPreferences();
    final existingBadges = _decodeStringSet(
      prefs.getString(_unlockedBadgesKey),
    );
    await prefs.setInt(
      _gamesCompletedKey,
      (prefs.getInt(_gamesCompletedKey) ?? 0) + 1,
    );
    if (isDailyChallenge) {
      await prefs.setInt(
        _dailyCompletedKey,
        (prefs.getInt(_dailyCompletedKey) ?? 0) + 1,
      );
    }

    if (mode == GameMode.classic && elapsed > 0) {
      final previous = prefs.getInt(_bestClassicSecondsKey);
      if (previous == null || elapsed < previous) {
        await prefs.setInt(_bestClassicSecondsKey, elapsed);
      }
    }
    if (mode == GameMode.speed) {
      final previous = prefs.getInt(_bestSpeedScoreKey);
      if (previous == null || score > previous) {
        await prefs.setInt(_bestSpeedScoreKey, score);
      }
    }
    if (stars > 0) {
      await prefs.setInt(
        _totalStarsKey,
        (prefs.getInt(_totalStarsKey) ?? 0) + stars.clamp(0, 3),
      );
    }

    final completions = _decodeCounterMap(
      prefs.getString(_categoryCompletionsKey),
    );
    completions[category.id] = (completions[category.id] ?? 0) + 1;
    await prefs.setString(_categoryCompletionsKey, jsonEncode(completions));

    final latestStats = await getStats();
    final unlockedBadges = rewardBadges
        .where((badge) => badge.isUnlocked(latestStats))
        .map((badge) => badge.id)
        .toSet();
    final newlyUnlocked = unlockedBadges.difference(existingBadges);
    if (newlyUnlocked.isNotEmpty ||
        unlockedBadges.length != existingBadges.length) {
      await prefs.setString(
        _unlockedBadgesKey,
        jsonEncode(unlockedBadges.toList(growable: false)..sort()),
      );
    }
    return LocalRewardResult(
      starsEarned: stars.clamp(0, 3),
      totalStars: latestStats.totalStars,
      newlyUnlockedBadgeIds: newlyUnlocked,
    );
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  static Map<String, int> _decodeCounterMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return {};
    }
  }

  static Set<String> _decodeStringSet(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => item.toString()).toSet();
    } catch (_) {
      return {};
    }
  }
}

class LocalRewardResult {
  const LocalRewardResult({
    required this.starsEarned,
    required this.totalStars,
    required this.newlyUnlockedBadgeIds,
  });

  final int starsEarned;
  final int totalStars;
  final Set<String> newlyUnlockedBadgeIds;
}

class RewardBadgeDefinition {
  const RewardBadgeDefinition({required this.id, required this.unlocksWhen});

  final String id;
  final bool Function(LocalStats stats) unlocksWhen;

  bool isUnlocked(LocalStats stats) => unlocksWhen(stats);
}

const rewardBadges = <RewardBadgeDefinition>[
  RewardBadgeDefinition(id: 'first_win', unlocksWhen: _hasCompletedOneGame),
  RewardBadgeDefinition(id: 'star_collector', unlocksWhen: _hasTenStars),
  RewardBadgeDefinition(id: 'daily_starter', unlocksWhen: _hasCompletedDaily),
  RewardBadgeDefinition(
    id: 'theme_explorer',
    unlocksWhen: _hasPlayedThreeThemes,
  ),
  RewardBadgeDefinition(id: 'speed_runner', unlocksWhen: _hasSpeedScore),
  RewardBadgeDefinition(id: 'word_hunter', unlocksWhen: _hasFoundFiftyWords),
];

bool _hasCompletedOneGame(LocalStats stats) => stats.gamesCompleted >= 1;

bool _hasTenStars(LocalStats stats) => stats.totalStars >= 10;

bool _hasCompletedDaily(LocalStats stats) => stats.dailyCompleted >= 1;

bool _hasPlayedThreeThemes(LocalStats stats) =>
    stats.categoryCompletions.length >= 3;

bool _hasSpeedScore(LocalStats stats) => (stats.bestSpeedScore ?? 0) >= 1000;

bool _hasFoundFiftyWords(LocalStats stats) => stats.totalWordsFound >= 50;
