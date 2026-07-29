import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/score_submission_guard.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';

void main() {
  late WordCategory category;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    category = wordCategories.first;
  });

  test('normalizes and accepts a valid classic submission', () async {
    final guard = ScoreSubmissionGuard();

    final submission = await guard.prepare(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      name: '  Ace   Player  ',
      time: 42,
      score: 500,
      maxScore: 500,
    );

    expect(submission.name, 'Ace Player');
    expect(submission.score, 500);
  });

  test('rejects unsupported name characters', () async {
    final guard = ScoreSubmissionGuard();

    expect(
      () => guard.prepare(
        category: category,
        difficulty: Difficulty.easy,
        mode: GameMode.classic,
        name: '<script>',
        time: 42,
        score: 500,
        maxScore: 500,
      ),
      throwsA(isA<ScoreSubmissionException>()),
    );
  });

  test('rejects incomplete classic scores', () async {
    final guard = ScoreSubmissionGuard();

    expect(
      () => guard.prepare(
        category: category,
        difficulty: Difficulty.easy,
        mode: GameMode.classic,
        name: 'Ace',
        time: 42,
        score: 450,
        maxScore: 500,
      ),
      throwsA(isA<ScoreSubmissionException>()),
    );
  });

  test('rejects impossible speed time', () async {
    final guard = ScoreSubmissionGuard();

    expect(
      () => guard.prepare(
        category: category,
        difficulty: Difficulty.easy,
        mode: GameMode.speed,
        name: 'Ace',
        time: 121,
        score: 250,
        maxScore: 500,
      ),
      throwsA(isA<ScoreSubmissionException>()),
    );
  });

  test('enforces a short per-board submit cooldown', () async {
    final guard = ScoreSubmissionGuard();
    await guard.markSubmitted(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.speed,
    );

    expect(
      () => guard.prepare(
        category: category,
        difficulty: Difficulty.easy,
        mode: GameMode.speed,
        name: 'Ace',
        time: 60,
        score: 250,
        maxScore: 500,
      ),
      throwsA(isA<ScoreSubmissionException>()),
    );
  });
}
