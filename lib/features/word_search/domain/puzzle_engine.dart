import 'dart:math';
import 'dart:ui';

import 'models.dart';

const wordColors = <Color>[
  Color(0xFFF97316),
  Color(0xFFA78BFA),
  Color(0xFF34D399),
  Color(0xFFF472B6),
  Color(0xFFFB923C),
  Color(0xFFFACC15),
  Color(0xFF60A5FA),
  Color(0xFFF87171),
  Color(0xFF4ADE80),
  Color(0xFFE879F9),
  Color(0xFF38BDF8),
  Color(0xFFFCD34D),
  Color(0xFF84CC16),
  Color(0xFFFB7185),
  Color(0xFF22D3EE),
  Color(0xFFC084FC),
  Color(0xFFFDE68A),
  Color(0xFF6EE7B7),
  Color(0xFF93C5FD),
  Color(0xFFFDA4AF),
];

const _dirs = <(int, int)>[
  (0, 1),
  (0, -1),
  (1, 0),
  (-1, 0),
  (1, 1),
  (1, -1),
  (-1, 1),
  (-1, -1),
];

const _easyDirs = <(int, int)>[(0, 1), (1, 0)];

const _mediumDirs = <(int, int)>[(0, 1), (0, -1), (1, 0), (-1, 0)];

List<(int, int)> _dirsForDifficulty(
  Difficulty difficulty, {
  PuzzleConfig? config,
}) {
  return switch (config?.directionMode) {
    PuzzleDirectionMode.horizontal => const [(0, 1)],
    PuzzleDirectionMode.forward => _easyDirs,
    PuzzleDirectionMode.reverse => _mediumDirs,
    PuzzleDirectionMode.all => _dirs,
    null => switch (difficulty) {
      Difficulty.easy => _easyDirs,
      Difficulty.medium => _mediumDirs,
      Difficulty.hard => _dirs,
    },
  };
}

bool isDirectionAllowedForDifficulty(
  Difficulty difficulty,
  int dr,
  int dc, {
  PuzzleConfig? config,
}) {
  return _dirsForDifficulty(difficulty, config: config).contains((dr, dc));
}

List<String> getWordsForDifficulty(List<String> words, Difficulty difficulty) {
  return getWordsForPuzzle(words, difficulty, config: difficulty.puzzleConfig);
}

List<String> getWordsForPuzzle(
  List<String> words,
  Difficulty difficulty, {
  required PuzzleConfig config,
}) {
  final ranked = words
      .where((word) => word.length <= config.gridSize)
      .indexed
      .toList(growable: false);
  ranked.sort((a, b) {
    final scoreA = _wordDifficultyScore(a.$2);
    final scoreB = _wordDifficultyScore(b.$2);
    final rank = switch (difficulty) {
      Difficulty.easy => scoreA.compareTo(scoreB),
      Difficulty.medium => (scoreA - 68).abs().compareTo((scoreB - 68).abs()),
      Difficulty.hard => scoreB.compareTo(scoreA),
    };
    if (rank != 0) {
      return rank;
    }
    return a.$1.compareTo(b.$1);
  });
  return ranked
      .map((entry) => entry.$2)
      .take(config.wordCount)
      .toList(growable: false);
}

int _wordDifficultyScore(String word) {
  var score = word.length * 10;
  for (final codeUnit in word.codeUnits) {
    final letter = String.fromCharCode(codeUnit);
    if ('JQXZ'.contains(letter)) {
      score += 6;
    } else if ('KFVWY'.contains(letter)) {
      score += 3;
    }
  }
  return score;
}

PuzzleState generatePuzzle(
  List<String> words,
  Difficulty difficulty, {
  Random? random,
  PuzzleConfig? config,
}) {
  final rand = random ?? Random();
  final resolvedConfig = config ?? difficulty.puzzleConfig;
  final size = resolvedConfig.gridSize;
  final sorted = [...words]..sort((a, b) => b.length.compareTo(a.length));
  final dirs = _dirsForDifficulty(difficulty, config: resolvedConfig);
  var bestGrid = List.generate(size, (_) => List.filled(size, ''));
  var bestPlacements = <WordPlacement>[];

  for (var attempt = 0; attempt < 360; attempt++) {
    final grid = List.generate(size, (_) => List.filled(size, ''));
    final placements = <WordPlacement>[];
    var complete = true;

    for (var wordIndex = 0; wordIndex < sorted.length; wordIndex++) {
      final word = sorted[wordIndex];
      final candidates = _placementCandidates(
        grid,
        word,
        dirs,
        size,
        rand,
        difficulty,
      );
      if (candidates.isEmpty) {
        complete = false;
        break;
      }
      final poolSize = min(candidates.length, switch (difficulty) {
        Difficulty.easy => 36,
        Difficulty.medium => 40,
        Difficulty.hard => 16,
      });
      final candidate = candidates[rand.nextInt(poolSize)];
      _placeTracked(
        grid,
        word,
        candidate.row,
        candidate.col,
        candidate.dr,
        candidate.dc,
      );
      placements.add(
        WordPlacement(
          word: word,
          startRow: candidate.row,
          startCol: candidate.col,
          dr: candidate.dr,
          dc: candidate.dc,
          color: wordColors[wordIndex % wordColors.length],
        ),
      );
    }

    if (placements.length > bestPlacements.length) {
      bestGrid = grid;
      bestPlacements = placements;
    }
    if (complete && placements.length == sorted.length) {
      bestGrid = grid;
      bestPlacements = placements;
      break;
    }
  }

  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      if (bestGrid[row][col].isEmpty) {
        bestGrid[row][col] = alphabet[rand.nextInt(alphabet.length)];
      }
    }
  }

  return PuzzleState(grid: bestGrid, placements: bestPlacements, size: size);
}

List<_PlacementCandidate> _placementCandidates(
  List<List<String>> grid,
  String word,
  List<(int, int)> dirs,
  int size,
  Random rand,
  Difficulty difficulty,
) {
  final candidates = <_PlacementCandidate>[];
  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      for (final dir in dirs) {
        if (_canPlace(grid, word, row, col, dir.$1, dir.$2, size)) {
          candidates.add(
            _PlacementCandidate(
              row: row,
              col: col,
              dr: dir.$1,
              dc: dir.$2,
              overlap: _placementOverlap(grid, word, row, col, dir.$1, dir.$2),
              order: rand.nextInt(0x7fffffff),
            ),
          );
        }
      }
    }
  }
  candidates.sort((a, b) {
    final overlap = switch (difficulty) {
      Difficulty.easy => a.overlap.compareTo(b.overlap),
      Difficulty.medium => a.overlap.compareTo(b.overlap),
      Difficulty.hard => b.overlap.compareTo(a.overlap),
    };
    if (overlap != 0) {
      return overlap;
    }
    return a.order.compareTo(b.order);
  });
  return candidates;
}

int _placementOverlap(
  List<List<String>> grid,
  String word,
  int row,
  int col,
  int dr,
  int dc,
) {
  var overlap = 0;
  for (var i = 0; i < word.length; i++) {
    if (grid[row + dr * i][col + dc * i] == word[i]) {
      overlap++;
    }
  }
  return overlap;
}

bool _canPlace(
  List<List<String>> grid,
  String word,
  int row,
  int col,
  int dr,
  int dc,
  int size,
) {
  for (var i = 0; i < word.length; i++) {
    final nextRow = row + dr * i;
    final nextCol = col + dc * i;
    if (nextRow < 0 || nextRow >= size || nextCol < 0 || nextCol >= size) {
      return false;
    }
    final current = grid[nextRow][nextCol];
    if (current.isNotEmpty && current != word[i]) {
      return false;
    }
  }
  return true;
}

List<GridCell> _placeTracked(
  List<List<String>> grid,
  String word,
  int row,
  int col,
  int dr,
  int dc,
) {
  final changedCells = <GridCell>[];
  for (var i = 0; i < word.length; i++) {
    final nextRow = row + dr * i;
    final nextCol = col + dc * i;
    if (grid[nextRow][nextCol].isEmpty) {
      grid[nextRow][nextCol] = word[i];
      changedCells.add(GridCell(nextRow, nextCol));
    }
  }
  return changedCells;
}

class _PlacementCandidate {
  const _PlacementCandidate({
    required this.row,
    required this.col,
    required this.dr,
    required this.dc,
    required this.overlap,
    required this.order,
  });

  final int row;
  final int col;
  final int dr;
  final int dc;
  final int overlap;
  final int order;
}

List<GridCell> getPlacementCells(WordPlacement placement) {
  return List.generate(
    placement.word.length,
    (i) => GridCell(
      placement.startRow + placement.dr * i,
      placement.startCol + placement.dc * i,
    ),
  );
}

(int, int) snapToDirection(int dr, int dc) {
  if (dr == 0 && dc == 0) {
    return (0, 0);
  }
  final angle = (atan2(dr, dc) * 180 / pi + 360) % 360;
  if (angle < 22.5 || angle >= 337.5) return (0, 1);
  if (angle < 67.5) return (1, 1);
  if (angle < 112.5) return (1, 0);
  if (angle < 157.5) return (1, -1);
  if (angle < 202.5) return (0, -1);
  if (angle < 247.5) return (-1, -1);
  if (angle < 292.5) return (-1, 0);
  return (-1, 1);
}

List<GridCell> getSelectionCells({
  required int startRow,
  required int startCol,
  required int endRow,
  required int endCol,
  required int size,
}) {
  final rowDelta = endRow - startRow;
  final colDelta = endCol - startCol;
  if (rowDelta == 0 && colDelta == 0) {
    return [GridCell(startRow, startCol)];
  }

  final dir = snapToDirection(rowDelta, colDelta);
  final steps = dir.$1 == 0
      ? colDelta.abs()
      : dir.$2 == 0
      ? rowDelta.abs()
      : max(rowDelta.abs(), colDelta.abs());
  final cells = <GridCell>[];
  for (var i = 0; i <= steps; i++) {
    final row = startRow + dir.$1 * i;
    final col = startCol + dir.$2 * i;
    if (row >= 0 && row < size && col >= 0 && col < size) {
      cells.add(GridCell(row, col));
    }
  }
  return cells;
}

WordPlacement? checkWordMatch(
  List<GridCell> cells,
  List<List<String>> grid,
  List<WordPlacement> placements,
) {
  if (cells.length < 2) {
    return null;
  }
  final word = cells.map((cell) => grid[cell.row][cell.col]).join();
  final reversed = word.split('').reversed.join();
  for (final placement in placements) {
    if (!placement.found &&
        (placement.word == word || placement.word == reversed)) {
      return placement;
    }
  }
  return null;
}

String formatSeconds(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remaining = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remaining';
}
