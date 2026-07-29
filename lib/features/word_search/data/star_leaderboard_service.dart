import 'package:shared_preferences/shared_preferences.dart';

import '../domain/level_progression.dart';
import '../domain/models.dart';
import 'kid_alias_store.dart';
import 'leaderboard_api.dart';
import 'level_progress_store.dart';

class StarLeaderboardSnapshot {
  const StarLeaderboardSnapshot({
    required this.entries,
    required this.totalStars,
    required this.completedLevels,
    required this.totalBestSeconds,
  });

  final List<LeaderboardEntry> entries;
  final int totalStars;
  final int completedLevels;
  final int totalBestSeconds;
}

class StarLeaderboardService {
  StarLeaderboardService({
    LeaderboardApi? api,
    LevelProgressStore? progressStore,
    KidAliasStore? aliasStore,
    SharedPreferences? preferences,
  }) : _api = api ?? LeaderboardApi(),
       _progressStore = progressStore ?? const LevelProgressStore(),
       _aliasStore = aliasStore ?? KidAliasStore(),
       _preferences = preferences;

  static const categoryId = 'all';
  static const difficulty = 'campaign';
  static const _lastStarsKey = 'star_leaderboard_sync_season2_stars';
  static const _lastTimeKey = 'star_leaderboard_sync_season2_time';

  static int get maxStars => campaignLevels.length * 3;

  final LeaderboardApi _api;
  final LevelProgressStore _progressStore;
  final KidAliasStore _aliasStore;
  final SharedPreferences? _preferences;

  Future<StarLeaderboardSnapshot> loadAndSync() async {
    final progress = await _progressStore.load();
    _validate(progress);
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final lastStars = preferences.getInt(_lastStarsKey);
    final lastTime = preferences.getInt(_lastTimeKey);
    final shouldSubmit =
        progress.totalStars > 0 &&
        (lastStars == null ||
            progress.totalStars > lastStars ||
            (progress.totalStars == lastStars &&
                progress.totalBestSeconds > 0 &&
                (lastTime == null || progress.totalBestSeconds < lastTime)));

    late List<LeaderboardEntry> entries;
    if (shouldSubmit) {
      final alias = await _aliasStore.getOrCreate();
      final result = await _api.submitScore(
        mode: LeaderboardMode.stars.storageName,
        categoryId: categoryId,
        difficulty: difficulty,
        name: alias,
        time: progress.totalBestSeconds,
        score: progress.totalStars,
      );
      entries = result.entries;
      await preferences.setInt(_lastStarsKey, progress.totalStars);
      await preferences.setInt(_lastTimeKey, progress.totalBestSeconds);
      if (entries.isEmpty) {
        entries = await _fetch();
      }
    } else {
      entries = await _fetch();
    }
    entries = _normalizeEntries(entries);

    return StarLeaderboardSnapshot(
      entries: entries,
      totalStars: progress.totalStars,
      completedLevels: progress.completedLevels,
      totalBestSeconds: progress.totalBestSeconds,
    );
  }

  Future<List<LeaderboardEntry>> _fetch() {
    return _api.fetchLeaderboard(
      LeaderboardMode.stars.storageName,
      categoryId,
      difficulty,
    );
  }

  List<LeaderboardEntry> _normalizeEntries(List<LeaderboardEntry> entries) {
    final bestByName = <String, LeaderboardEntry>{};
    for (final entry in entries) {
      if (!KidAliasStore.isSafeAlias(entry.name) ||
          entry.score < 0 ||
          entry.score > maxStars ||
          entry.time < 0) {
        continue;
      }
      final previous = bestByName[entry.name];
      if (previous == null ||
          entry.score > previous.score ||
          (entry.score == previous.score && entry.time < previous.time)) {
        bestByName[entry.name] = entry;
      }
    }
    final normalized = bestByName.values.toList(growable: false)
      ..sort((a, b) {
        final byStars = b.score.compareTo(a.score);
        return byStars != 0 ? byStars : a.time.compareTo(b.time);
      });
    return normalized;
  }

  void _validate(LevelProgressSnapshot progress) {
    if (progress.totalStars < 0 ||
        progress.totalStars > maxStars ||
        progress.completedLevels < 0 ||
        progress.completedLevels > campaignLevels.length ||
        progress.totalStars < progress.completedLevels ||
        progress.totalStars > progress.completedLevels * 3 ||
        progress.totalBestSeconds < 0) {
      throw const LeaderboardException('Star progress could not be verified.');
    }
  }
}
