import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/local_stats_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records found words and completed games', () async {
    const store = LocalStatsStore();
    final category = wordCategories.first;

    await store.recordWordFound(category: category);
    await store.recordWordFound(category: category);
    await store.recordGameCompleted(
      category: category,
      mode: GameMode.classic,
      elapsed: 45,
      score: 500,
      isDailyChallenge: true,
    );

    final stats = await store.getStats();

    expect(stats.totalWordsFound, 2);
    expect(stats.gamesCompleted, 1);
    expect(stats.dailyCompleted, 1);
    expect(stats.bestClassicSeconds, 45);
    expect(stats.favoriteCategory?.id, category.id);
  });

  test('keeps best classic time and best speed score', () async {
    const store = LocalStatsStore();
    final category = wordCategories.first;

    await store.recordGameCompleted(
      category: category,
      mode: GameMode.classic,
      elapsed: 80,
      score: 1000,
      isDailyChallenge: false,
    );
    await store.recordGameCompleted(
      category: category,
      mode: GameMode.classic,
      elapsed: 60,
      score: 1000,
      isDailyChallenge: false,
    );
    await store.recordGameCompleted(
      category: category,
      mode: GameMode.speed,
      elapsed: 120,
      score: 700,
      isDailyChallenge: false,
    );
    await store.recordGameCompleted(
      category: category,
      mode: GameMode.speed,
      elapsed: 120,
      score: 900,
      isDailyChallenge: false,
    );

    final stats = await store.getStats();

    expect(stats.bestClassicSeconds, 60);
    expect(stats.bestSpeedScore, 900);
    expect(stats.gamesCompleted, 4);
  });
}
