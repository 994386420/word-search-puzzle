import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class SavedPuzzleProgress {
  const SavedPuzzleProgress({
    required this.puzzle,
    required this.foundWords,
    required this.score,
    required this.elapsed,
    required this.hintsLeft,
    this.contentVersion = 0,
    this.hintsUsed = 0,
    this.hintedWords = const <String>{},
    this.prepaidHintsLeft = 0,
    this.completed = false,
  });

  final PuzzleState puzzle;
  final Set<String> foundWords;
  final int score;
  final int elapsed;
  final int hintsLeft;
  final int contentVersion;
  final int hintsUsed;
  final Set<String> hintedWords;
  final int prepaidHintsLeft;
  final bool completed;
}

class ProgressStore {
  static const _key = 'word_search_progress_v2';
  static const _legacyKey = 'word_search_progress_v1';
  static const _tutorialSeenKey = 'word_search_tutorial_seen';
  static const _homeStartGuideSeenKey = 'word_search_home_start_guide_seen';
  static const _firstFindCelebrationSeenKey =
      'word_search_first_find_celebration_seen';
  static const _reviewVoiceGuideSeenKey = 'word_search_review_voice_guide_seen';

  Future<SavedPuzzleProgress?> loadPuzzleProgress(
    String categoryId,
    String difficulty,
  ) async {
    final data = await _loadV2();
    final raw = data[_entryKey(categoryId, difficulty)];
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    try {
      final puzzle = _puzzleFromJson(raw['puzzle'] as Map<String, dynamic>);
      final foundWords = Set<String>.from(
        (raw['foundWords'] as List? ?? const []).map((item) => item.toString()),
      );
      return SavedPuzzleProgress(
        puzzle: puzzle,
        foundWords: foundWords,
        score: (raw['score'] as num?)?.toInt() ?? 0,
        elapsed: (raw['elapsed'] as num?)?.toInt() ?? 0,
        hintsLeft: (raw['hintsLeft'] as num?)?.toInt() ?? 3,
        contentVersion: (raw['contentVersion'] as num?)?.toInt() ?? 0,
        hintsUsed: (raw['hintsUsed'] as num?)?.toInt() ?? 0,
        hintedWords: Set<String>.from(
          (raw['hintedWords'] as List? ?? const []).map(
            (item) => item.toString(),
          ),
        ),
        prepaidHintsLeft:
            (raw['prepaidHintsLeft'] as num?)?.toInt().clamp(0, 3) ?? 0,
        completed: raw['completed'] == true || _isComplete(puzzle, foundWords),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePuzzleProgress(
    String categoryId,
    String difficulty,
    SavedPuzzleProgress progress,
  ) async {
    final data = await _loadV2();
    data[_entryKey(categoryId, difficulty)] = {
      'puzzle': _puzzleToJson(progress.puzzle),
      'foundWords': progress.foundWords.toList(growable: false),
      'score': progress.score,
      'elapsed': progress.elapsed,
      'hintsLeft': progress.hintsLeft,
      'contentVersion': progress.contentVersion,
      'hintsUsed': progress.hintsUsed,
      'hintedWords': progress.hintedWords.toList(growable: false),
      'prepaidHintsLeft': progress.prepaidHintsLeft,
      'completed': progress.completed,
    };
    await _saveV2(data);
  }

  Future<Set<String>> loadLegacyFoundWords(
    String categoryId,
    String difficulty,
  ) async {
    final data = await _loadLegacy();
    return Set<String>.from(
      data[_entryKey(categoryId, difficulty)] ?? const [],
    );
  }

  Future<int> getCategoryProgress(String categoryId, String difficulty) async {
    final data = await _loadV2();
    final raw = data[_entryKey(categoryId, difficulty)];
    if (raw is Map<String, dynamic>) {
      return (raw['foundWords'] as List? ?? const []).length;
    }
    final legacy = await _loadLegacy();
    return (legacy[_entryKey(categoryId, difficulty)] ?? const []).length;
  }

  Future<Map<String, int>> getDifficultyProgress(String difficulty) async {
    final result = <String, int>{};
    final legacy = await _loadLegacy();
    for (final entry in legacy.entries) {
      if (entry.key.endsWith('_$difficulty')) {
        result[entry.key.substring(
              0,
              entry.key.length - difficulty.length - 1,
            )] =
            entry.value.length;
      }
    }

    final data = await _loadV2();
    for (final entry in data.entries) {
      if (entry.key.endsWith('_$difficulty')) {
        final raw = entry.value;
        if (raw is Map<String, dynamic>) {
          result[entry.key.substring(
                0,
                entry.key.length - difficulty.length - 1,
              )] =
              (raw['foundWords'] as List? ?? const []).length;
        }
      }
    }
    return result;
  }

  Future<int> getTotalFoundWords() async {
    var total = 0;
    final legacy = await _loadLegacy();
    for (final words in legacy.values) {
      total += words.length;
    }
    final data = await _loadV2();
    for (final raw in data.values) {
      if (raw is Map<String, dynamic>) {
        total += (raw['foundWords'] as List? ?? const []).length;
      }
    }
    return total;
  }

  Future<void> clearCategory(String categoryId, String difficulty) async {
    final data = await _loadV2();
    data.remove(_entryKey(categoryId, difficulty));
    await _saveV2(data);

    final legacy = await _loadLegacy();
    legacy.remove(_entryKey(categoryId, difficulty));
    await _saveLegacy(legacy);
  }

  Future<bool> hasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialSeenKey) ?? false;
  }

  Future<void> markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialSeenKey, true);
  }

  Future<bool> hasSeenHomeStartGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_homeStartGuideSeenKey) ?? false;
  }

  Future<void> markHomeStartGuideSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeStartGuideSeenKey, true);
  }

  Future<bool> hasSeenFirstFindCelebration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstFindCelebrationSeenKey) ?? false;
  }

  Future<void> markFirstFindCelebrationSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstFindCelebrationSeenKey, true);
  }

  Future<bool> hasSeenReviewVoiceGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reviewVoiceGuideSeenKey) ?? false;
  }

  Future<void> markReviewVoiceGuideSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewVoiceGuideSeenKey, true);
  }

  Future<void> resetGuideState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tutorialSeenKey);
    await prefs.remove(_homeStartGuideSeenKey);
    await prefs.remove(_firstFindCelebrationSeenKey);
    await prefs.remove(_reviewVoiceGuideSeenKey);
  }

  Future<Map<String, dynamic>> _loadV2() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return {};
      }
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveV2(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<Map<String, List<String>>> _loadLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_legacyKey);
      if (raw == null || raw.isEmpty) {
        return {};
      }
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return parsed.map(
        (key, value) => MapEntry(
          key,
          value is List ? value.map((item) => item.toString()).toList() : [],
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLegacy(Map<String, List<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyKey, jsonEncode(data));
  }

  Map<String, dynamic> _puzzleToJson(PuzzleState puzzle) {
    return {
      'size': puzzle.size,
      'grid': puzzle.grid,
      'placements': puzzle.placements
          .map(
            (placement) => {
              'word': placement.word,
              'startRow': placement.startRow,
              'startCol': placement.startCol,
              'dr': placement.dr,
              'dc': placement.dc,
              'color': placement.color.toARGB32(),
            },
          )
          .toList(growable: false),
    };
  }

  PuzzleState _puzzleFromJson(Map<String, dynamic> json) {
    final grid = (json['grid'] as List)
        .map((row) => (row as List).map((cell) => cell.toString()).toList())
        .toList();
    final placements = (json['placements'] as List)
        .map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return WordPlacement(
            word: item['word'].toString(),
            startRow: (item['startRow'] as num).toInt(),
            startCol: (item['startCol'] as num).toInt(),
            dr: (item['dr'] as num).toInt(),
            dc: (item['dc'] as num).toInt(),
            color: Color((item['color'] as num).toInt()),
          );
        })
        .toList(growable: false);
    return PuzzleState(
      grid: grid,
      placements: placements,
      size: (json['size'] as num).toInt(),
    );
  }

  String _entryKey(String categoryId, String difficulty) {
    return '${categoryId}_$difficulty';
  }

  bool _isComplete(PuzzleState puzzle, Set<String> foundWords) {
    if (puzzle.placements.isEmpty) {
      return false;
    }
    return puzzle.placements.every(
      (placement) => foundWords.contains(placement.word),
    );
  }
}
