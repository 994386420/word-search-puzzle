import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/kid_word_catalog.dart';
import 'package:word_search_puzzle/features/word_search/domain/level_progression.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';

void main() {
  test('builds thirty deterministic levels for every theme', () {
    expect(levelsRequiredToUnlockNextTheme, lessThan(levelsPerTheme));
    expect(campaignLevels, hasLength(wordCategories.length * levelsPerTheme));
    expect(campaignLevels.map((level) => level.id).toSet(), hasLength(180));

    for (final category in wordCategories) {
      final levels = campaignLevels
          .where((level) => level.category.id == category.id)
          .toList(growable: false);
      expect(levels, hasLength(levelsPerTheme));
      expect(levels.first.themeLevel, 1);
      expect(levels.last.themeLevel, levelsPerTheme);
    }
  });

  test('campaign difficulty ramps inside each theme pack', () {
    final animals = wordCategories.first;
    expect(levelForTheme(animals, 1).difficulty, Difficulty.easy);
    expect(levelForTheme(animals, 8).difficulty, Difficulty.easy);
    expect(levelForTheme(animals, 9).difficulty, Difficulty.medium);
    expect(levelForTheme(animals, 20).difficulty, Difficulty.medium);
    expect(levelForTheme(animals, 21).difficulty, Difficulty.hard);
    expect(levelForTheme(animals, 30).difficulty, Difficulty.hard);
  });

  test('campaign levels have stable seeds and valid word counts', () {
    final rebuilt = buildCampaignLevels();
    for (var index = 0; index < campaignLevels.length; index++) {
      final level = campaignLevels[index];
      expect(rebuilt[index].seed, level.seed);
      expect(rebuilt[index].words, level.words);
      expect(level.words, hasLength(level.puzzleConfig.wordCount));
      expect(
        level.words.every((word) => word.length <= level.puzzleConfig.gridSize),
        isTrue,
      );
    }
  });

  test('campaign uses the full twenty-five-word theme vocabulary', () {
    for (final category in wordCategories) {
      final usedWords = campaignLevels
          .where((level) => level.category.id == category.id)
          .expand((level) => level.words)
          .toSet();

      expect(usedWords, category.words.toSet());
    }
  });

  test('adjacent campaign levels do not repeat the same word set', () {
    for (final category in wordCategories) {
      final levels = campaignLevels
          .where((level) => level.category.id == category.id)
          .toList(growable: false);
      for (var index = 1; index < levels.length; index++) {
        final previous = levels[index - 1].words.toSet();
        final current = levels[index].words.toSet();
        final overlap = previous.intersection(current).length;

        expect(current, isNot(previous));
        expect(overlap, lessThan(previous.length));
      }
    }
  });

  test('picture campaign levels only use illustrated words', () {
    for (final level in campaignLevels.where(
      (level) => level.clueMode == ClueMode.pictures,
    )) {
      expect(
        level.words.every(
          (word) =>
              kidWordVisualAssetFor(word, categoryId: level.category.id) !=
              null,
        ),
        isTrue,
      );
    }
  });

  test('picture campaign levels use the complete expanded vocabulary', () {
    for (final category in wordCategories) {
      final pictureWords = campaignLevels
          .where(
            (level) =>
                level.category.id == category.id &&
                level.clueMode == ClueMode.pictures,
          )
          .expand((level) => level.words)
          .toSet();

      expect(
        pictureWords,
        category.words.toSet(),
        reason: '${category.id} picture levels should rotate all 25 words',
      );
    }
  });

  test('expanded words appear within the first ten levels of every theme', () {
    for (final category in wordCategories) {
      final expandedWords = category.words.skip(15).toSet();
      final earlyWords = campaignLevels
          .where(
            (level) =>
                level.category.id == category.id && level.themeLevel <= 10,
          )
          .expand((level) => level.words)
          .toSet();

      expect(
        earlyWords.intersection(expandedWords),
        isNotEmpty,
        reason: '${category.id} should introduce expanded words early',
      );
    }
  });

  test('campaign rules introduce new mechanics in stages', () {
    expect(puzzleConfigForThemeLevel(1).gridSize, 7);
    expect(puzzleConfigForThemeLevel(1).wordCount, 4);
    expect(
      puzzleConfigForThemeLevel(1).directionMode,
      PuzzleDirectionMode.horizontal,
    );
    expect(
      puzzleConfigForThemeLevel(2).directionMode,
      PuzzleDirectionMode.forward,
    );
    expect(
      puzzleConfigForThemeLevel(5).directionMode,
      PuzzleDirectionMode.reverse,
    );
    expect(
      puzzleConfigForThemeLevel(17).directionMode,
      PuzzleDirectionMode.all,
    );
    expect(puzzleConfigForThemeLevel(30).gridSize, 12);
    expect(puzzleConfigForThemeLevel(30).wordCount, 12);
  });

  test('campaign alternates learning clue modes', () {
    expect(clueModeForThemeLevel(1), ClueMode.pictures);
    expect(clueModeForThemeLevel(3), ClueMode.words);
    expect(clueModeForThemeLevel(5), ClueMode.sounds);
    expect(clueModeForThemeLevel(7), ClueMode.memory);
  });

  test('next campaign level stays in pack before moving themes', () {
    final animals = wordCategories.first;
    expect(nextCampaignLevel(levelForTheme(animals, 1))?.themeLevel, 2);
    final afterAnimals = nextCampaignLevel(
      levelForTheme(animals, levelsPerTheme),
    );
    expect(afterAnimals?.category.id, wordCategories[1].id);
    expect(afterAnimals?.themeLevel, 1);
  });

  test('derives levels from cumulative found words', () {
    expect(levelRecommendationForFoundWords(0).level, 1);
    expect(levelRecommendationForFoundWords(19).level, 1);
    expect(levelRecommendationForFoundWords(20).level, 2);
    expect(levelRecommendationForFoundWords(40).level, 3);
  });

  test('rotates recommended category by level', () {
    final firstPath = List.generate(
      wordCategories.length,
      (index) =>
          levelRecommendationForFoundWords(wordsPerLevel * index).category.id,
    );

    expect(firstPath, ['animals', 'food', 'nature', 'sports', 'space', 'tech']);
    expect(
      levelRecommendationForFoundWords(
        wordsPerLevel * wordCategories.length,
      ).category.id,
      'animals',
    );
  });

  test('ramps difficulty at level milestones', () {
    expect(levelRecommendationForFoundWords(0).difficulty, Difficulty.easy);
    expect(
      levelRecommendationForFoundWords(wordsPerLevel * 5).difficulty,
      Difficulty.easy,
    );
    expect(
      levelRecommendationForFoundWords(wordsPerLevel * 6).difficulty,
      Difficulty.medium,
    );
    expect(
      levelRecommendationForFoundWords(wordsPerLevel * 15).difficulty,
      Difficulty.hard,
    );
  });
}
