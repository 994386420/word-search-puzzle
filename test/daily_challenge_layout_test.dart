import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/app/app_theme.dart';
import 'package:word_search_puzzle/features/word_search/data/appearance_preference_store.dart';
import 'package:word_search_puzzle/features/word_search/data/daily_challenge_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/presentation/screens/daily_challenge_screen.dart';

void main() {
  testWidgets('daily reward path stays usable across phone widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final width in [320.0, 360.0, 430.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: WordSearchAppTheme.light(AppSkin.fresh),
          home: DailyChallengeScreen(
            challenge: DailyChallenge(
              dateKey: '20260729',
              category: wordCategories.first,
              difficulty: Difficulty.easy,
              seed: 28,
              completedToday: false,
              streak: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'daily challenge overflowed at ${width.toInt()}dp',
      );
      expect(find.text("TODAY'S PUZZLE"), findsOneWidget);
      final boardFinder = find.byKey(const ValueKey('daily-reward-board'));
      expect(boardFinder, findsOneWidget);
      final board = tester.widget<Image>(boardFinder);
      expect(
        (board.image as AssetImage).assetName,
        'assets/ui/clay/daily_reward_board_weekday_3_active.webp',
      );
      final boardSize = tester.getSize(boardFinder);
      expect(boardSize.width / boardSize.height, closeTo(970 / 780, 0.01));
    }
  });

  testWidgets('daily reward board follows weekday and completion', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    Future<String> assetFor({
      required String dateKey,
      required bool completedToday,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WordSearchAppTheme.light(AppSkin.fresh),
          home: DailyChallengeScreen(
            challenge: DailyChallenge(
              dateKey: dateKey,
              category: wordCategories.first,
              difficulty: Difficulty.easy,
              seed: 1,
              completedToday: completedToday,
              streak: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final board = tester.widget<Image>(
        find.byKey(const ValueKey('daily-reward-board')),
      );
      return (board.image as AssetImage).assetName;
    }

    const dateKeys = [
      '20260727',
      '20260728',
      '20260729',
      '20260730',
      '20260731',
      '20260801',
      '20260802',
    ];
    for (var index = 0; index < dateKeys.length; index++) {
      final weekday = index + 1;
      expect(
        await assetFor(dateKey: dateKeys[index], completedToday: false),
        'assets/ui/clay/daily_reward_board_weekday_${weekday}_active.webp',
      );
      expect(
        await assetFor(dateKey: dateKeys[index], completedToday: true),
        'assets/ui/clay/daily_reward_board_weekday_${weekday}_complete.webp',
      );
    }
  });
}
