import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/level_progress_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/level_progression.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts at the first campaign level', () async {
    const store = LevelProgressStore();

    final snapshot = await store.load();

    expect(snapshot.activeLevel.id, firstCampaignLevel().id);
    expect(snapshot.results, isEmpty);
  });

  test('records completion and advances to the next level', () async {
    const store = LevelProgressStore();
    final first = firstCampaignLevel();

    final snapshot = await store.recordCompleted(
      first,
      stars: 2,
      elapsedSeconds: 72,
    );

    expect(snapshot.resultFor(first)?.stars, 2);
    expect(snapshot.resultFor(first)?.bestSeconds, 72);
    expect(snapshot.activeLevel.id, nextCampaignLevel(first)?.id);
    expect(snapshot.completedInTheme(first.category.id), 1);
  });

  test('keeps the best stars and shortest completion time', () async {
    const store = LevelProgressStore();
    final first = firstCampaignLevel();

    await store.recordCompleted(first, stars: 3, elapsedSeconds: 80);
    await store.recordCompleted(first, stars: 1, elapsedSeconds: 95);
    final snapshot = await store.recordCompleted(
      first,
      stars: 2,
      elapsedSeconds: 61,
    );

    expect(snapshot.resultFor(first)?.stars, 3);
    expect(snapshot.resultFor(first)?.bestSeconds, 61);
  });

  test('finds the next incomplete level in a theme', () async {
    const store = LevelProgressStore();
    final animals = wordCategories.first;
    await store.recordCompleted(
      levelForTheme(animals, 1),
      stars: 2,
      elapsedSeconds: 60,
    );
    final snapshot = await store.load();

    expect(snapshot.nextLevelInTheme(animals).themeLevel, 2);
  });

  test('summarizes unique best stars for the global ranking', () async {
    const store = LevelProgressStore();
    final first = firstCampaignLevel();
    final second = nextCampaignLevel(first)!;
    await store.recordCompleted(first, stars: 2, elapsedSeconds: 72);
    await store.recordCompleted(first, stars: 3, elapsedSeconds: 61);
    final snapshot = await store.recordCompleted(
      second,
      stars: 2,
      elapsedSeconds: 54,
    );

    expect(snapshot.totalStars, 5);
    expect(snapshot.completedLevels, 2);
    expect(snapshot.totalBestSeconds, 115);
  });
}
