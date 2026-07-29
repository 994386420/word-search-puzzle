import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/daily_challenge_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns a stable challenge for the same day', () async {
    const store = DailyChallengeStore();
    final first = await store.getToday(now: DateTime(2026, 7, 7, 9));
    final second = await store.getToday(now: DateTime(2026, 7, 7, 21));

    expect(second.dateKey, first.dateKey);
    expect(second.category.id, first.category.id);
    expect(second.difficulty, first.difficulty);
    expect(second.seed, first.seed);
    expect(second.progressId, 'daily_${first.dateKey}');
    expect(first.weekday, DateTime.tuesday);
  });

  test('markCompleted starts and preserves today streak', () async {
    const store = DailyChallengeStore();

    final streak = await store.markCompleted(now: DateTime(2026, 7, 7));
    final duplicate = await store.markCompleted(now: DateTime(2026, 7, 7, 18));
    final today = await store.getToday(now: DateTime(2026, 7, 7, 20));

    expect(streak, 1);
    expect(duplicate, 1);
    expect(today.completedToday, isTrue);
    expect(today.streak, 1);
  });

  test('markCompleted increments consecutive day streaks', () async {
    const store = DailyChallengeStore();

    await store.markCompleted(now: DateTime(2026, 7, 7));
    final streak = await store.markCompleted(now: DateTime(2026, 7, 8));
    final today = await store.getToday(now: DateTime(2026, 7, 8, 8));

    expect(streak, 2);
    expect(today.completedToday, isTrue);
    expect(today.streak, 2);
  });
}
