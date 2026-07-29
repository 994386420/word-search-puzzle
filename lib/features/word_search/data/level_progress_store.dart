import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/level_progression.dart';
import '../domain/models.dart';

class LevelResult {
  const LevelResult({required this.stars, required this.bestSeconds});

  final int stars;
  final int bestSeconds;

  bool get completed => stars > 0;

  Map<String, dynamic> toJson() => {'stars': stars, 'bestSeconds': bestSeconds};

  factory LevelResult.fromJson(Map<String, dynamic> json) {
    return LevelResult(
      stars: ((json['stars'] as num?)?.toInt() ?? 0).clamp(0, 3),
      bestSeconds: (json['bestSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class LevelProgressSnapshot {
  const LevelProgressSnapshot({
    required this.activeLevelId,
    required this.results,
  });

  final String activeLevelId;
  final Map<String, LevelResult> results;

  LevelDefinition get activeLevel =>
      campaignLevelById(activeLevelId) ?? firstCampaignLevel();

  LevelResult? resultFor(LevelDefinition level) => results[level.id];

  bool isCompleted(LevelDefinition level) =>
      resultFor(level)?.completed ?? false;

  int get totalStars => campaignLevels.fold(
    0,
    (sum, level) => sum + (resultFor(level)?.stars ?? 0),
  );

  int get completedLevels =>
      campaignLevels.where((level) => isCompleted(level)).length;

  int get totalBestSeconds => campaignLevels.fold(0, (sum, level) {
    final result = resultFor(level);
    return sum + (result?.completed == true ? result!.bestSeconds : 0);
  });

  int completedInTheme(String categoryId) {
    return campaignLevels
        .where((level) => level.category.id == categoryId && isCompleted(level))
        .length;
  }

  int starsInTheme(String categoryId) {
    return campaignLevels
        .where((level) => level.category.id == categoryId)
        .fold(0, (sum, level) => sum + (resultFor(level)?.stars ?? 0));
  }

  LevelDefinition nextLevelInTheme(WordCategory category) {
    for (final level in campaignLevels.where(
      (level) => level.category.id == category.id,
    )) {
      if (!isCompleted(level)) {
        return level;
      }
    }
    return levelForTheme(category, levelsPerTheme);
  }
}

class LevelProgressStore {
  const LevelProgressStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _key = 'campaign_level_progress_v1';
  final SharedPreferences? _preferences;

  Future<LevelProgressSnapshot> load() async {
    final prefs = await _getPreferences();
    try {
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return _emptySnapshot();
      }
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final rawResults = Map<String, dynamic>.from(
        json['results'] as Map? ?? const {},
      );
      final results = <String, LevelResult>{};
      for (final entry in rawResults.entries) {
        if (entry.value is Map) {
          results[entry.key] = LevelResult.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      final activeId = json['activeLevelId']?.toString();
      return LevelProgressSnapshot(
        activeLevelId:
            campaignLevelById(activeId)?.id ?? firstCampaignLevel().id,
        results: results,
      );
    } catch (_) {
      return _emptySnapshot();
    }
  }

  Future<void> setActiveLevel(LevelDefinition level) async {
    final snapshot = await load();
    await _save(
      LevelProgressSnapshot(activeLevelId: level.id, results: snapshot.results),
    );
  }

  Future<LevelProgressSnapshot> recordCompleted(
    LevelDefinition level, {
    required int stars,
    required int elapsedSeconds,
  }) async {
    final snapshot = await load();
    final previous = snapshot.resultFor(level);
    final safeStars = stars.clamp(1, 3);
    final safeSeconds = elapsedSeconds < 0 ? 0 : elapsedSeconds;
    final bestSeconds = previous == null || previous.bestSeconds <= 0
        ? safeSeconds
        : safeSeconds <= 0
        ? previous.bestSeconds
        : safeSeconds < previous.bestSeconds
        ? safeSeconds
        : previous.bestSeconds;
    final results = Map<String, LevelResult>.from(snapshot.results)
      ..[level.id] = LevelResult(
        stars: previous == null || safeStars > previous.stars
            ? safeStars
            : previous.stars,
        bestSeconds: bestSeconds,
      );
    final next = nextCampaignLevel(level);
    final updated = LevelProgressSnapshot(
      activeLevelId: next?.id ?? level.id,
      results: results,
    );
    await _save(updated);
    return updated;
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  LevelProgressSnapshot _emptySnapshot() {
    return LevelProgressSnapshot(
      activeLevelId: firstCampaignLevel().id,
      results: const {},
    );
  }

  Future<void> _save(LevelProgressSnapshot snapshot) async {
    final prefs = await _getPreferences();
    await prefs.setString(
      _key,
      jsonEncode({
        'activeLevelId': snapshot.activeLevelId,
        'results': snapshot.results.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      }),
    );
  }
}
