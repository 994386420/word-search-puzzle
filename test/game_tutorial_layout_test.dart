import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/voice_guide_service.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/presentation/screens/game_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'voice_guide_enabled': false});
    await VoiceGuideService.instance.setGuideEnabled(false);
  });

  testWidgets('tutorial stays outside and aligned with the puzzle board', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in <Size>[
      const Size(360, 800),
      const Size(411, 923),
      const Size(480, 853),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            category: wordCategories.first,
            difficulty: Difficulty.easy,
            mode: GameMode.classic,
            randomSeed: 17,
            onViewLeaderboard: (_, _, _, _) {},
          ),
        ),
      );

      for (var attempt = 0; attempt < 20; attempt++) {
        if (find.byKey(const ValueKey('tutorial-card')).evaluate().isNotEmpty &&
            find
                .byKey(const ValueKey('gesture-guide-board'))
                .evaluate()
                .isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }

      final board = tester.getRect(
        find.byKey(const ValueKey('puzzle-grid-board')),
      );
      final gestureGuide = tester.getRect(
        find.byKey(const ValueKey('gesture-guide-board')),
      );
      final tutorialCard = tester.getRect(
        find.byKey(const ValueKey('tutorial-card')),
      );

      expect(gestureGuide, board, reason: 'Gesture guide mismatch at $size');
      expect(
        tutorialCard.overlaps(board),
        isFalse,
        reason: 'Tutorial covers the puzzle board at $size',
      );
      expect(find.byTooltip('Got it'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
