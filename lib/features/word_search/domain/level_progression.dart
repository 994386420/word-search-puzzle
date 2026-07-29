import 'dart:math';

import 'categories.dart';
import 'kid_word_catalog.dart';
import 'models.dart';

const wordsPerLevel = 20;
const levelsPerTheme = 30;
const levelsRequiredToUnlockNextTheme = 5;

class LevelDefinition {
  const LevelDefinition({
    required this.globalLevel,
    required this.themeLevel,
    required this.category,
    required this.difficulty,
    required this.clueMode,
    required this.puzzleConfig,
    required this.words,
    required this.seed,
  });

  final int globalLevel;
  final int themeLevel;
  final WordCategory category;
  final Difficulty difficulty;
  final ClueMode clueMode;
  final PuzzleConfig puzzleConfig;
  final List<String> words;
  final int seed;

  String get id => 'level_${category.id}_$themeLevel';
  String get progressId => id;
}

List<LevelDefinition> buildCampaignLevels() {
  final levels = <LevelDefinition>[];
  for (
    var categoryIndex = 0;
    categoryIndex < wordCategories.length;
    categoryIndex++
  ) {
    final usageCounts = <String, int>{};
    final recentSets = <Set<String>>[];
    for (var themeLevel = 1; themeLevel <= levelsPerTheme; themeLevel++) {
      final recentWords = recentSets.expand((words) => words).toSet();
      final level = _buildLevel(
        categoryIndex: categoryIndex,
        themeLevel: themeLevel,
        recentWords: recentWords,
        usageCounts: usageCounts,
      );
      levels.add(level);
      for (final word in level.words) {
        usageCounts.update(word, (count) => count + 1, ifAbsent: () => 1);
      }
      recentSets.add(level.words.toSet());
      if (recentSets.length > 2) {
        recentSets.removeAt(0);
      }
    }
  }
  return levels;
}

final campaignLevels = buildCampaignLevels();

LevelDefinition firstCampaignLevel() => campaignLevels.first;

LevelDefinition? campaignLevelById(String? id) {
  if (id == null || id.isEmpty) {
    return null;
  }
  for (final level in campaignLevels) {
    if (level.id == id) {
      return level;
    }
  }
  return null;
}

LevelDefinition levelForTheme(WordCategory category, int themeLevel) {
  final safeLevel = themeLevel.clamp(1, levelsPerTheme);
  return campaignLevels.firstWhere(
    (level) =>
        level.category.id == category.id && level.themeLevel == safeLevel,
  );
}

LevelDefinition? nextCampaignLevel(LevelDefinition level) {
  final index = campaignLevels.indexWhere((item) => item.id == level.id);
  if (index < 0 || index + 1 >= campaignLevels.length) {
    return null;
  }
  return campaignLevels[index + 1];
}

Difficulty difficultyForThemeLevel(int themeLevel) {
  final safeLevel = themeLevel.clamp(1, levelsPerTheme);
  if (safeLevel >= 21) {
    return Difficulty.hard;
  }
  if (safeLevel >= 9) {
    return Difficulty.medium;
  }
  return Difficulty.easy;
}

PuzzleConfig puzzleConfigForThemeLevel(int themeLevel) {
  final level = themeLevel.clamp(1, levelsPerTheme);
  if (level == 1) {
    return const PuzzleConfig(
      gridSize: 7,
      wordCount: 4,
      directionMode: PuzzleDirectionMode.horizontal,
    );
  }
  if (level == 2) {
    return const PuzzleConfig(
      gridSize: 7,
      wordCount: 5,
      directionMode: PuzzleDirectionMode.forward,
    );
  }
  if (level <= 4) {
    return const PuzzleConfig(
      gridSize: 8,
      wordCount: 5,
      directionMode: PuzzleDirectionMode.forward,
    );
  }
  if (level <= 8) {
    return const PuzzleConfig(
      gridSize: 8,
      wordCount: 6,
      directionMode: PuzzleDirectionMode.reverse,
    );
  }
  if (level <= 12) {
    return const PuzzleConfig(
      gridSize: 9,
      wordCount: 7,
      directionMode: PuzzleDirectionMode.reverse,
    );
  }
  if (level <= 16) {
    return const PuzzleConfig(
      gridSize: 10,
      wordCount: 8,
      directionMode: PuzzleDirectionMode.reverse,
    );
  }
  if (level <= 20) {
    return const PuzzleConfig(
      gridSize: 10,
      wordCount: 9,
      directionMode: PuzzleDirectionMode.all,
    );
  }
  if (level <= 25) {
    return const PuzzleConfig(
      gridSize: 11,
      wordCount: 10,
      directionMode: PuzzleDirectionMode.all,
    );
  }
  return const PuzzleConfig(
    gridSize: 12,
    wordCount: 12,
    directionMode: PuzzleDirectionMode.all,
  );
}

ClueMode clueModeForThemeLevel(int themeLevel) {
  final level = themeLevel.clamp(1, levelsPerTheme);
  if (level <= 2) {
    return ClueMode.pictures;
  }
  return switch ((level - 3) % 5) {
    0 => ClueMode.words,
    1 => ClueMode.pictures,
    2 => ClueMode.sounds,
    3 => ClueMode.pictures,
    _ => ClueMode.memory,
  };
}

LevelDefinition _buildLevel({
  required int categoryIndex,
  required int themeLevel,
  required Set<String> recentWords,
  required Map<String, int> usageCounts,
}) {
  final category = wordCategories[categoryIndex];
  final difficulty = difficultyForThemeLevel(themeLevel);
  final puzzleConfig = puzzleConfigForThemeLevel(themeLevel);
  final clueMode = clueModeForThemeLevel(themeLevel);
  final seed = 17041 + categoryIndex * 100003 + themeLevel * 7919;
  final selectedWords = selectKidWordsForRound(
    category.words,
    difficulty,
    config: puzzleConfig,
    random: Random(seed),
    clueMode: clueMode,
    categoryId: category.id,
    recentWords: recentWords,
    usageCounts: usageCounts,
  );
  return LevelDefinition(
    globalLevel: categoryIndex * levelsPerTheme + themeLevel,
    themeLevel: themeLevel,
    category: category,
    difficulty: difficulty,
    clueMode: clueMode,
    puzzleConfig: puzzleConfig,
    words: selectedWords,
    seed: seed,
  );
}

class LevelRecommendation {
  const LevelRecommendation({
    required this.level,
    required this.totalFoundWords,
    required this.currentProgress,
    required this.category,
    required this.difficulty,
  });

  final int level;
  final int totalFoundWords;
  final int currentProgress;
  final WordCategory category;
  final Difficulty difficulty;
}

LevelRecommendation levelRecommendationForFoundWords(int totalFoundWords) {
  final safeTotal = totalFoundWords < 0 ? 0 : totalFoundWords;
  final level = safeTotal ~/ wordsPerLevel + 1;
  return LevelRecommendation(
    level: level,
    totalFoundWords: safeTotal,
    currentProgress: safeTotal % wordsPerLevel,
    category: categoryForLevel(level),
    difficulty: difficultyForLevel(level),
  );
}

WordCategory categoryForLevel(int level) {
  final safeLevel = level < 1 ? 1 : level;
  return wordCategories[(safeLevel - 1) % wordCategories.length];
}

Difficulty difficultyForLevel(int level) {
  if (level >= 16) {
    return Difficulty.hard;
  }
  if (level >= 7) {
    return Difficulty.medium;
  }
  return Difficulty.easy;
}
