import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/voice_guide_service.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/presentation/screens/game_screen.dart';
import 'package:word_search_puzzle/features/word_search/presentation/widgets/word_illustration.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'voice_guide_enabled': false});
    await VoiceGuideService.instance.setGuideEnabled(false);
  });

  test('six picture clues fit in one row at the standard game width', () {
    final layout = calculatePictureClueGridLayout(
      availableWidth: 386,
      itemCount: 6,
    );

    expect(layout.columns, 6);
    expect(layout.rows, 1);
    expect(layout.pictureSize, greaterThanOrEqualTo(52));
  });

  test('picture clues expand to multiple visible rows on narrow screens', () {
    final sixClues = calculatePictureClueGridLayout(
      availableWidth: 276,
      itemCount: 6,
    );
    final twelveClues = calculatePictureClueGridLayout(
      availableWidth: 276,
      itemCount: 12,
    );

    expect(sixClues.rows, 2);
    expect(twelveClues.rows, 3);
    expect(sixClues.pictureSize, greaterThanOrEqualTo(44));
    expect(twelveClues.pictureSize, greaterThanOrEqualTo(44));
    expect(twelveClues.contentHeight, greaterThan(sixClues.contentHeight));
  });

  test('five picture clues fit inside a 360dp game viewport', () {
    final layout = calculatePictureClueGridLayout(
      availableWidth: 310,
      itemCount: 5,
    );
    const spacing = 6.0;
    const chipPadding = 6.0;
    final rowWidth =
        layout.columns * (layout.pictureSize + chipPadding) +
        (layout.columns - 1) * spacing;

    expect(layout.columns, 5);
    expect(layout.rows, 1);
    expect(rowWidth, lessThanOrEqualTo(310));
  });

  test('calculated rows never exceed the available width', () {
    for (final width in [240.0, 276.0, 386.0]) {
      for (var count = 4; count <= 12; count++) {
        final layout = calculatePictureClueGridLayout(
          availableWidth: width,
          itemCount: count,
        );
        const spacing = 6.0;
        const chipPadding = 6.0;
        final rowWidth =
            layout.columns * (layout.pictureSize + chipPadding) +
            (layout.columns - 1) * spacing;

        expect(rowWidth, lessThanOrEqualTo(width + 0.001));
        expect(layout.rows * layout.columns, greaterThanOrEqualTo(count));
      }
    }
  });

  testWidgets('picture mode keeps one prominent clue on a narrow phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          category: wordCategories.first,
          difficulty: Difficulty.easy,
          mode: GameMode.classic,
          clueMode: ClueMode.pictures,
          randomSeed: 17,
          onViewLeaderboard: (_, _, _, _) {},
        ),
      ),
    );

    for (var attempt = 0; attempt < 20; attempt++) {
      if (find.byType(WordIllustration).evaluate().length == 6) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }

    final illustrations = find.byType(WordIllustration);
    expect(illustrations, findsNWidgets(6));
    final widths = List<double>.generate(
      6,
      (index) => tester.getSize(illustrations.at(index)).width,
    );
    final largest = widths.reduce((a, b) => a > b ? a : b);
    final smallest = widths.reduce((a, b) => a < b ? a : b);
    expect(largest, greaterThanOrEqualTo(100));
    expect(largest / smallest, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });
}
