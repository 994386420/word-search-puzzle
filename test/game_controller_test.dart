import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/progress_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/kid_word_catalog.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/domain/puzzle_engine.dart';
import 'package:word_search_puzzle/features/word_search/presentation/controllers/game_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('classic mode restores the same puzzle and true score', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(11),
    );
    await first.start();
    final firstGrid = first.puzzle!.grid.map((row) => row.join()).join('|');
    final placement = first.placements.first;
    await first.markFound(placement);
    final expectedScore = Difficulty.easy.wordScore * placement.word.length;
    first.dispose();

    final second = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(99),
    );
    await second.start();
    final secondGrid = second.puzzle!.grid.map((row) => row.join()).join('|');

    expect(secondGrid, firstGrid);
    expect(
      second.placements.firstWhere((p) => p.word == placement.word).found,
      isTrue,
    );
    expect(second.score, expectedScore);
    second.dispose();
  });

  test('campaign replay word pools preserve an unfinished puzzle', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressId: 'level_animals_replay',
      levelWords: const ['LION', 'TIGER', 'PANDA', 'WOLF', 'KOALA', 'MONKEY'],
      levelWordPool: category.words,
      progressStore: ProgressStore(),
      random: Random(13),
    );
    await first.start();
    final firstGrid = first.puzzle!.grid.map((row) => row.join()).join('|');
    final foundWord = first.placements.first.word;
    await first.markFound(first.placements.first);
    first.dispose();

    final second = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressId: 'level_animals_replay',
      levelWords: const ['ZEBRA', 'HIPPO', 'PARROT', 'EAGLE', 'RHINO', 'SHARK'],
      levelWordPool: category.words,
      progressStore: ProgressStore(),
      random: Random(19),
    );
    await second.start();
    final secondGrid = second.puzzle!.grid.map((row) => row.join()).join('|');

    expect(secondGrid, firstGrid);
    expect(
      second.placements.firstWhere((word) => word.word == foundWord).found,
      isTrue,
    );
    second.dispose();
  });

  test('classic mode persists remaining hints', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(21),
    );
    await first.start();
    await first.revealHint();
    await first.revealHint();
    expect(first.hintsLeft, 1);
    first.dispose();

    final second = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(22),
    );
    await second.start();

    expect(second.hintsLeft, 1);
    second.dispose();
  });

  test('classic mode persists prepaid refill hints', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(26),
    );
    await first.start();
    await first.revealHint();
    await first.revealHint();
    await first.revealHint();
    await first.refillHints();
    await first.revealHint();
    expect(first.hintsLeft, 2);
    expect(first.prepaidHintsLeft, 2);
    first.dispose();

    final second = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(27),
    );
    await second.start();

    expect(second.hintsLeft, 2);
    expect(second.prepaidHintsLeft, 2);
    second.dispose();
  });

  test('classic mode restores words that used a hint', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(32),
    );
    await first.start();
    await first.revealHint();
    final hintedWord = first.hintedWords.single;
    first.dispose();

    final second = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(33),
    );
    await second.start();

    expect(second.hintedWords, contains(hintedWord));
    second.dispose();
  });

  test(
    'classic mode discards saved puzzles from old difficulty specs',
    () async {
      final oldPlacements = ['LION', 'TIGER', 'ZEBRA', 'EAGLE', 'RHINO'].indexed
          .map(
            (entry) => {
              'word': entry.$2,
              'startRow': entry.$1,
              'startCol': 0,
              'dr': 0,
              'dc': 1,
              'color': 0xFFF97316,
            },
          )
          .toList(growable: false);
      SharedPreferences.setMockInitialValues({
        'word_search_progress_v2': jsonEncode({
          'animals_easy': {
            'puzzle': {
              'size': Difficulty.easy.gridSize,
              'grid': List.generate(
                Difficulty.easy.gridSize,
                (_) => List.filled(Difficulty.easy.gridSize, 'A'),
              ),
              'placements': oldPlacements,
            },
            'foundWords': <String>[],
            'score': 0,
            'elapsed': 0,
            'hintsLeft': 3,
            'completed': false,
          },
        }),
      });
      final controller = GameController(
        category: wordCategories.first,
        difficulty: Difficulty.easy,
        mode: GameMode.classic,
        progressStore: ProgressStore(),
        random: Random(23),
      );

      await controller.start();

      expect(controller.puzzle?.size, Difficulty.easy.gridSize);
      expect(controller.totalCount, Difficulty.easy.wordCount);
      controller.dispose();
    },
  );

  test(
    'classic mode discards saved puzzles with outdated directions',
    () async {
      final category = wordCategories.first;
      final easyWords = getWordsForDifficulty(category.words, Difficulty.easy);
      final oldPlacements = easyWords.indexed
          .map(
            (entry) => {
              'word': entry.$2,
              'startRow': 0,
              'startCol': entry.$1,
              'dr': 1,
              'dc': 1,
              'color': 0xFFF97316,
            },
          )
          .toList(growable: false);
      SharedPreferences.setMockInitialValues({
        'word_search_progress_v2': jsonEncode({
          'animals_easy': {
            'puzzle': {
              'size': Difficulty.easy.gridSize,
              'grid': List.generate(
                Difficulty.easy.gridSize,
                (_) => List.filled(Difficulty.easy.gridSize, 'A'),
              ),
              'placements': oldPlacements,
            },
            'foundWords': <String>[],
            'score': 0,
            'elapsed': 0,
            'hintsLeft': 3,
            'completed': false,
          },
        }),
      });
      final controller = GameController(
        category: category,
        difficulty: Difficulty.easy,
        mode: GameMode.classic,
        progressStore: ProgressStore(),
        random: Random(25),
      );

      await controller.start();

      expect(
        controller.placements.every(
          (placement) => isDirectionAllowedForDifficulty(
            Difficulty.easy,
            placement.dr,
            placement.dc,
          ),
        ),
        isTrue,
      );
      controller.dispose();
    },
  );

  test('classic mode refreshes puzzles from older content versions', () async {
    final category = wordCategories.first;
    final words = getWordsForDifficulty(category.words, Difficulty.easy);
    final legacyPuzzle = generatePuzzle(
      words,
      Difficulty.easy,
      random: Random(28),
    );
    final store = _LegacyContentProgressStore(
      SavedPuzzleProgress(
        puzzle: legacyPuzzle,
        foundWords: const <String>{},
        score: 0,
        elapsed: 0,
        hintsLeft: GameController.maxHints,
      ),
    );
    final controller = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: store,
      random: Random(29),
    );

    await controller.start();

    expect(store.clearCount, 1);
    expect(
      store.lastSaved?.contentVersion,
      GameController.puzzleContentVersion,
    );
    expect(controller.totalCount, Difficulty.easy.wordCount);
    controller.dispose();
  });

  test('classic hints escalate from first letter to full path', () async {
    final controller = GameController(
      category: wordCategories.first,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(24),
    );
    await controller.start();

    await controller.revealHint();
    expect(controller.hintTier, 1);
    expect(controller.hintCells, hasLength(1));

    await controller.revealHint();
    expect(controller.hintTier, 2);
    expect(controller.hintCells.length, greaterThanOrEqualTo(1));
    expect(controller.hintCells.length, lessThanOrEqualTo(2));

    await controller.revealHint();
    expect(controller.hintTier, 3);
    expect(controller.hintCells.length, greaterThanOrEqualTo(2));
    expect(controller.hintsLeft, 0);
    controller.dispose();
  });

  test('classic mode throttles timer progress saves', () async {
    final store = _CountingProgressStore();
    final controller = GameController(
      category: wordCategories.first,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: store,
      random: Random(31),
    );
    await controller.start();

    expect(store.saveCount, 1);
    await Future<void>.delayed(const Duration(milliseconds: 3200));

    expect(store.saveCount, 1);
    controller.dispose();
  });

  test('pausing immediately persists the current classic game', () async {
    final store = _CountingProgressStore();
    final controller = GameController(
      category: wordCategories.first,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: store,
      random: Random(34),
    );
    await controller.start();
    expect(store.saveCount, 1);

    controller.pause();
    await Future<void>.delayed(Duration.zero);

    expect(controller.paused, isTrue);
    expect(store.saveCount, 2);
    expect(store.lastSaved, isNotNull);

    controller.pause();
    await Future<void>.delayed(Duration.zero);
    expect(store.saveCount, 2);
    controller.dispose();
  });

  test('classic mode starts fresh when saved puzzle is complete', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(41),
    );
    await first.start();
    for (final placement in first.placements.toList(growable: false)) {
      await first.markFound(placement);
    }
    expect(first.won, isTrue);
    first.dispose();

    final second = GameController(
      category: category,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      progressStore: ProgressStore(),
      random: Random(42),
    );
    await second.start();

    expect(second.won, isFalse);
    expect(second.foundCount, 0);
    expect(second.score, 0);
    expect(second.placements.every((placement) => !placement.found), isTrue);
    second.dispose();
  });

  test('randomSeed generates a deterministic speed puzzle', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.medium,
      mode: GameMode.speed,
      randomSeed: 7007,
    );
    final second = GameController(
      category: category,
      difficulty: Difficulty.medium,
      mode: GameMode.speed,
      randomSeed: 7007,
    );

    await first.start();
    await second.start();
    final firstGrid = first.puzzle!.grid.map((row) => row.join()).join('|');
    final secondGrid = second.puzzle!.grid.map((row) => row.join()).join('|');

    expect(secondGrid, firstGrid);
    first.dispose();
    second.dispose();
  });

  test('different seeds vary the free-play word set', () async {
    final category = wordCategories.first;
    final first = GameController(
      category: category,
      difficulty: Difficulty.medium,
      mode: GameMode.speed,
      randomSeed: 7007,
    );
    final second = GameController(
      category: category,
      difficulty: Difficulty.medium,
      mode: GameMode.speed,
      randomSeed: 8118,
    );

    await first.start();
    await second.start();

    expect(
      second.placements.map((placement) => placement.word).toSet(),
      isNot(first.placements.map((placement) => placement.word).toSet()),
    );
    first.dispose();
    second.dispose();
  });

  test('picture mode only selects words with bundled artwork', () async {
    final category = wordCategories.first;
    final controller = GameController(
      category: category,
      difficulty: Difficulty.hard,
      mode: GameMode.speed,
      clueMode: ClueMode.pictures,
      randomSeed: 9229,
    );

    await controller.start();

    expect(controller.placements, hasLength(Difficulty.hard.wordCount));
    expect(
      controller.placements.every(
        (placement) =>
            kidWordVisualAssetFor(placement.word, categoryId: category.id) !=
            null,
      ),
      isTrue,
    );
    controller.dispose();
  });

  test(
    'custom progressId keeps daily progress separate from normal progress',
    () async {
      final category = wordCategories.first;
      final daily = GameController(
        category: category,
        difficulty: Difficulty.easy,
        mode: GameMode.classic,
        progressStore: ProgressStore(),
        randomSeed: 42,
        progressId: 'daily_20260707',
      );
      await daily.start();
      final placement = daily.placements.first;
      await daily.markFound(placement);
      daily.dispose();

      final normal = GameController(
        category: category,
        difficulty: Difficulty.easy,
        mode: GameMode.classic,
        progressStore: ProgressStore(),
        randomSeed: 42,
      );
      await normal.start();

      expect(
        normal.placements
            .firstWhere((item) => item.word == placement.word)
            .found,
        isFalse,
      );
      normal.dispose();
    },
  );
}

class _CountingProgressStore extends ProgressStore {
  int saveCount = 0;
  SavedPuzzleProgress? lastSaved;

  @override
  Future<SavedPuzzleProgress?> loadPuzzleProgress(
    String categoryId,
    String difficulty,
  ) async {
    return null;
  }

  @override
  Future<Set<String>> loadLegacyFoundWords(
    String categoryId,
    String difficulty,
  ) async {
    return <String>{};
  }

  @override
  Future<void> savePuzzleProgress(
    String categoryId,
    String difficulty,
    SavedPuzzleProgress progress,
  ) async {
    saveCount += 1;
    lastSaved = progress;
  }

  @override
  Future<void> clearCategory(String categoryId, String difficulty) async {}
}

class _LegacyContentProgressStore extends ProgressStore {
  _LegacyContentProgressStore(this.saved);

  final SavedPuzzleProgress saved;
  int clearCount = 0;
  SavedPuzzleProgress? lastSaved;

  @override
  Future<SavedPuzzleProgress?> loadPuzzleProgress(
    String categoryId,
    String difficulty,
  ) async => saved;

  @override
  Future<Set<String>> loadLegacyFoundWords(
    String categoryId,
    String difficulty,
  ) async => <String>{};

  @override
  Future<void> savePuzzleProgress(
    String categoryId,
    String difficulty,
    SavedPuzzleProgress progress,
  ) async {
    lastSaved = progress;
  }

  @override
  Future<void> clearCategory(String categoryId, String difficulty) async {
    clearCount += 1;
  }
}
