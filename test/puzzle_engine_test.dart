import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/level_progression.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/domain/puzzle_engine.dart';

void main() {
  test('custom campaign specs control board size and directions', () {
    const config = PuzzleConfig(
      gridSize: 7,
      wordCount: 4,
      directionMode: PuzzleDirectionMode.horizontal,
    );
    final words = getWordsForPuzzle(
      wordCategories.first.words,
      Difficulty.easy,
      config: config,
    );
    final puzzle = generatePuzzle(
      words,
      Difficulty.easy,
      random: Random(9),
      config: config,
    );

    expect(puzzle.size, 7);
    expect(puzzle.placements, hasLength(4));
    expect(
      puzzle.placements.every(
        (placement) => placement.dr == 0 && placement.dc == 1,
      ),
      isTrue,
    );
  });

  test('representative campaign stages place every configured word', () {
    const milestones = [1, 2, 5, 9, 17, 21, 30];
    for (final category in wordCategories) {
      for (final themeLevel in milestones) {
        final level = levelForTheme(category, themeLevel);
        final puzzle = generatePuzzle(
          level.words,
          level.difficulty,
          random: Random(level.seed),
          config: level.puzzleConfig,
        );

        expect(puzzle.size, level.puzzleConfig.gridSize);
        expect(
          puzzle.placements.map((placement) => placement.word).toSet(),
          level.words.toSet(),
          reason: '${category.id} level $themeLevel should place every word',
        );
      }
    }
  });

  test('every campaign level generates a complete playable puzzle', () {
    for (final level in campaignLevels) {
      final puzzle = generatePuzzle(
        level.words,
        level.difficulty,
        random: Random(level.seed),
        config: level.puzzleConfig,
      );
      final placedWords = puzzle.placements
          .map((placement) => placement.word)
          .toSet();

      expect(
        puzzle.size,
        level.puzzleConfig.gridSize,
        reason: '${level.id} should use its configured board size',
      );
      expect(
        placedWords,
        level.words.toSet(),
        reason: '${level.id} should place every configured word',
      );
      for (final placement in puzzle.placements) {
        final cells = getPlacementCells(placement);
        expect(
          cells.every(
            (cell) =>
                cell.row >= 0 &&
                cell.row < puzzle.size &&
                cell.col >= 0 &&
                cell.col < puzzle.size,
          ),
          isTrue,
          reason: '${level.id} should keep ${placement.word} on the board',
        );
        expect(
          isDirectionAllowedForDifficulty(
            level.difficulty,
            placement.dr,
            placement.dc,
            config: level.puzzleConfig,
          ),
          isTrue,
          reason: '${level.id} should use only unlocked directions',
        );
        expect(
          cells.map((cell) => puzzle.grid[cell.row][cell.col]).join(),
          placement.word,
          reason: '${level.id} should spell ${placement.word} correctly',
        );
      }
    }
  });

  test('difficulty specs scale word count and puzzle space', () {
    expect(Difficulty.easy.gridSize, 8);
    expect(Difficulty.medium.gridSize, 10);
    expect(Difficulty.hard.gridSize, 12);
    expect(Difficulty.easy.wordCount, 6);
    expect(Difficulty.medium.wordCount, 9);
    expect(Difficulty.hard.wordCount, 12);
  });

  test('word selection gets harder while keeping advanced counts balanced', () {
    final words = [
      'LION',
      'TIGER',
      'ELEPHANT',
      'GIRAFFE',
      'ZEBRA',
      'MONKEY',
      'PENGUIN',
      'DOLPHIN',
      'EAGLE',
      'PYTHON',
      'CHEETAH',
      'GORILLA',
      'LEOPARD',
      'JAGUAR',
      'RHINO',
      'HIPPO',
      'FLAMINGO',
      'PARROT',
      'KOALA',
      'PANDA',
      'KANGAROO',
      'WOLF',
      'SHARK',
      'PEACOCK',
      'FALCON',
    ];
    final easy = getWordsForDifficulty(words, Difficulty.easy);
    final medium = getWordsForDifficulty(words, Difficulty.medium);
    final hard = getWordsForDifficulty(words, Difficulty.hard);

    expect(easy, hasLength(Difficulty.easy.wordCount));
    expect(medium, hasLength(Difficulty.medium.wordCount));
    expect(hard, hasLength(Difficulty.hard.wordCount));
    expect(hard.length, greaterThan(medium.length));
    expect(_averageLength(medium), greaterThan(_averageLength(easy)));
    expect(_averageLength(hard), greaterThan(_averageLength(medium)));
    expect(
      easy.every((word) => word.length <= Difficulty.easy.gridSize),
      isTrue,
    );
    expect(hard, contains('ELEPHANT'));
    expect(hard, contains('KANGAROO'));
  });

  test('configured puzzles place the full requested word count', () {
    for (
      var categoryIndex = 0;
      categoryIndex < wordCategories.length;
      categoryIndex++
    ) {
      final category = wordCategories[categoryIndex];
      for (final difficulty in Difficulty.values) {
        final words = getWordsForDifficulty(category.words, difficulty);
        final puzzle = generatePuzzle(
          words,
          difficulty,
          random: Random(categoryIndex * 31 + difficulty.index),
        );

        expect(
          words,
          hasLength(difficulty.wordCount),
          reason: '${category.id} ${difficulty.name} should have enough words',
        );
        expect(
          puzzle.placements.map((placement) => placement.word).toSet(),
          words.toSet(),
          reason: '${category.id} ${difficulty.name} should place every word',
        );
      }
    }
  });

  test('generatePuzzle places every requested easy word', () {
    final words = ['LION', 'TIGER', 'ZEBRA', 'EAGLE'];
    final puzzle = generatePuzzle(words, Difficulty.easy, random: Random(7));

    expect(puzzle.size, Difficulty.easy.gridSize);
    expect(
      puzzle.placements.map((placement) => placement.word),
      containsAll(words),
    );
    for (final placement in puzzle.placements) {
      final spelled = getPlacementCells(
        placement,
      ).map((cell) => puzzle.grid[cell.row][cell.col]).join();
      expect(spelled, placement.word);
    }
  });

  test('easy puzzle uses only forward horizontal and vertical words', () {
    final words = ['LION', 'TIGER', 'ZEBRA', 'EAGLE'];
    final puzzle = generatePuzzle(words, Difficulty.easy, random: Random(13));

    for (final placement in puzzle.placements) {
      expect([(0, 1), (1, 0)], contains((placement.dr, placement.dc)));
    }
  });

  test('medium puzzle avoids diagonal words', () {
    final words = [
      'LION',
      'TIGER',
      'ZEBRA',
      'EAGLE',
      'MONKEY',
      'PANDA',
      'RHINO',
      'WOLF',
    ];
    final puzzle = generatePuzzle(words, Difficulty.medium, random: Random(17));

    for (final placement in puzzle.placements) {
      expect(placement.dr == 0 || placement.dc == 0, isTrue);
    }
  });

  test('checkWordMatch accepts reverse selections', () {
    final puzzle = generatePuzzle(['LION'], Difficulty.easy, random: Random(2));
    final placement = puzzle.placements.single;
    final reversedCells = getPlacementCells(placement).reversed.toList();

    final match = checkWordMatch(reversedCells, puzzle.grid, puzzle.placements);

    expect(match?.word, 'LION');
  });
}

double _averageLength(List<String> words) {
  return words.fold<int>(0, (sum, word) => sum + word.length) / words.length;
}
