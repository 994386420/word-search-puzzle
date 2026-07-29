import 'package:flutter/material.dart';

enum Difficulty { easy, medium, hard }

enum GameMode { classic, speed }

enum LeaderboardMode { classic, speed, stars }

enum ClueMode { words, pictures, sounds, memory }

enum PuzzleDirectionMode { horizontal, forward, reverse, all }

class PuzzleConfig {
  const PuzzleConfig({
    required this.gridSize,
    required this.wordCount,
    required this.directionMode,
  });

  final int gridSize;
  final int wordCount;
  final PuzzleDirectionMode directionMode;
}

extension DifficultyX on Difficulty {
  int get gridSize => switch (this) {
    Difficulty.easy => 8,
    Difficulty.medium => 10,
    Difficulty.hard => 12,
  };

  int get wordCount => switch (this) {
    Difficulty.easy => 6,
    Difficulty.medium => 9,
    Difficulty.hard => 12,
  };

  int get wordScore => switch (this) {
    Difficulty.easy => 50,
    Difficulty.medium => 100,
    Difficulty.hard => 200,
  };

  String get label => switch (this) {
    Difficulty.easy => 'Easy',
    Difficulty.medium => 'Medium',
    Difficulty.hard => 'Hard',
  };

  Color get color => switch (this) {
    Difficulty.easy => const Color(0xFF10B981),
    Difficulty.medium => const Color(0xFF3B82F6),
    Difficulty.hard => const Color(0xFFEF4444),
  };

  String get storageName => name;

  PuzzleConfig get puzzleConfig => PuzzleConfig(
    gridSize: gridSize,
    wordCount: wordCount,
    directionMode: switch (this) {
      Difficulty.easy => PuzzleDirectionMode.forward,
      Difficulty.medium => PuzzleDirectionMode.reverse,
      Difficulty.hard => PuzzleDirectionMode.all,
    },
  );
}

extension GameModeX on GameMode {
  String get label => switch (this) {
    GameMode.classic => 'Classic',
    GameMode.speed => 'Speed',
  };

  String get storageName => name;
}

extension LeaderboardModeX on LeaderboardMode {
  String get storageName => name;

  static LeaderboardMode fromGameMode(GameMode mode) => switch (mode) {
    GameMode.classic => LeaderboardMode.classic,
    GameMode.speed => LeaderboardMode.speed,
  };
}

extension ClueModeX on ClueMode {
  String get storageName => name;
}

class WordCategory {
  const WordCategory({
    required this.id,
    required this.name,
    required this.words,
    required this.description,
    required this.accentColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.assetPath,
  });

  final String id;
  final String name;
  final List<String> words;
  final String description;
  final Color accentColor;
  final Color gradientStart;
  final Color gradientEnd;
  final String assetPath;
}

class GridCell {
  const GridCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridCell && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);
}

class WordPlacement {
  const WordPlacement({
    required this.word,
    required this.startRow,
    required this.startCol,
    required this.dr,
    required this.dc,
    required this.color,
    this.found = false,
  });

  final String word;
  final int startRow;
  final int startCol;
  final int dr;
  final int dc;
  final Color color;
  final bool found;

  WordPlacement copyWith({bool? found}) {
    return WordPlacement(
      word: word,
      startRow: startRow,
      startCol: startCol,
      dr: dr,
      dc: dc,
      color: color,
      found: found ?? this.found,
    );
  }
}

class PuzzleState {
  const PuzzleState({
    required this.grid,
    required this.placements,
    required this.size,
  });

  final List<List<String>> grid;
  final List<WordPlacement> placements;
  final int size;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.time,
    required this.score,
    required this.date,
  });

  final String name;
  final int time;
  final int score;
  final DateTime date;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: (json['name'] ?? '').toString(),
      time: (json['time'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'time': time,
    'score': score,
    'date': date.toIso8601String(),
  };
}

class ScoreSubmissionResult {
  const ScoreSubmissionResult({required this.rank, required this.entries});

  final int rank;
  final List<LeaderboardEntry> entries;
}
