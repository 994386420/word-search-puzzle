import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/progress_store.dart';
import '../../domain/models.dart';
import '../../domain/puzzle_engine.dart';
import '../../domain/kid_word_catalog.dart';

class GameController extends ChangeNotifier {
  GameController({
    required this.category,
    required this.difficulty,
    required this.mode,
    this.clueMode = ClueMode.words,
    this.progressId,
    this.randomSeed,
    this.levelWords,
    this.levelWordPool,
    this.puzzleConfig,
    this.onCompleted,
    ProgressStore? progressStore,
    Random? random,
  }) : _progressStore = progressStore ?? ProgressStore(),
       _random = random ?? (randomSeed == null ? Random() : Random(randomSeed));

  static const speedSeconds = 120;
  static const maxHints = 3;
  static const puzzleContentVersion = 1;

  final WordCategory category;
  final Difficulty difficulty;
  final GameMode mode;
  final ClueMode clueMode;
  final String? progressId;
  final int? randomSeed;
  final List<String>? levelWords;
  final List<String>? levelWordPool;
  final PuzzleConfig? puzzleConfig;
  final VoidCallback? onCompleted;
  final ProgressStore _progressStore;
  final Random _random;

  PuzzleState? puzzle;
  List<WordPlacement> placements = [];
  int score = 0;
  int elapsed = 0;
  int timeLeft = speedSeconds;
  bool paused = false;
  bool won = false;
  GridCell? hintCell;
  List<GridCell> hintCells = [];
  int hintTier = 0;
  WordPlacement? lastFound;
  int lastPoints = 0;
  int hintsLeft = maxHints;
  int hintsUsed = 0;
  int prepaidHintsLeft = 0;
  final Set<String> hintedWords = <String>{};

  Timer? _timer;
  Timer? _hintTimer;
  Timer? _toastTimer;
  bool _disposed = false;

  bool get isSpeed => mode == GameMode.speed;
  String get _progressCategoryId => progressId ?? category.id;
  int get foundCount => placements.where((placement) => placement.found).length;
  int get totalCount => placements.length;
  int get maxScore => placements.fold(
    0,
    (sum, placement) => sum + difficulty.wordScore * placement.word.length,
  );
  double get progress {
    if (isSpeed) {
      return timeLeft / speedSeconds;
    }
    if (totalCount == 0) {
      return 0;
    }
    return foundCount / totalCount;
  }

  Future<void> start() async {
    final resolvedConfig = puzzleConfig ?? difficulty.puzzleConfig;
    final sourceWords = levelWords ?? category.words;
    final allowedSourceWords = levelWordPool ?? sourceWords;
    final candidateWords = kidWordCandidatesForRound(
      allowedSourceWords,
      difficulty,
      config: resolvedConfig,
      clueMode: clueMode,
      categoryId: category.id,
    );
    final words = levelWords == null
        ? selectKidWordsForRound(
            sourceWords,
            difficulty,
            config: resolvedConfig,
            random: _random,
            clueMode: clueMode,
            categoryId: category.id,
          )
        : getWordsForPuzzle(levelWords!, difficulty, config: resolvedConfig);
    var savedProgress = isSpeed
        ? null
        : await _progressStore.loadPuzzleProgress(
            _progressCategoryId,
            difficulty.storageName,
          );
    if (savedProgress != null &&
        !_matchesDifficultySpec(savedProgress, candidateWords)) {
      await _progressStore.clearCategory(
        _progressCategoryId,
        difficulty.storageName,
      );
      savedProgress = null;
    }
    if (savedProgress != null && _isCompletedProgress(savedProgress)) {
      await _progressStore.clearCategory(
        _progressCategoryId,
        difficulty.storageName,
      );
      savedProgress = null;
    }
    final generated =
        savedProgress?.puzzle ??
        generatePuzzle(
          words,
          difficulty,
          random: _random,
          config: resolvedConfig,
        );
    final savedWords =
        savedProgress?.foundWords ??
        (isSpeed
            ? <String>{}
            : progressId == null
            ? await _progressStore.loadLegacyFoundWords(
                category.id,
                difficulty.storageName,
              )
            : <String>{});
    puzzle = generated;
    placements = generated.placements
        .map(
          (placement) =>
              placement.copyWith(found: savedWords.contains(placement.word)),
        )
        .toList(growable: false);
    score = savedProgress?.score ?? _scoreForFoundWords(placements);
    elapsed = savedProgress?.elapsed ?? 0;
    hintsLeft = isSpeed ? maxHints : (savedProgress?.hintsLeft ?? maxHints);
    hintsUsed = isSpeed ? 0 : (savedProgress?.hintsUsed ?? 0);
    prepaidHintsLeft = isSpeed ? 0 : (savedProgress?.prepaidHintsLeft ?? 0);
    hintedWords.clear();
    if (!isSpeed && savedProgress != null) {
      hintedWords.addAll(savedProgress.hintedWords);
    }
    timeLeft = speedSeconds;
    paused = false;
    won = false;
    hintCell = null;
    hintCells = [];
    hintTier = 0;
    lastFound = null;
    lastPoints = 0;
    notifyListeners();
    await _persistProgress();
    _restartTimer();
  }

  Future<void> restart() async {
    _timer?.cancel();
    _hintTimer?.cancel();
    _toastTimer?.cancel();
    if (!isSpeed) {
      await _progressStore.clearCategory(
        _progressCategoryId,
        difficulty.storageName,
      );
    }
    await start();
  }

  void togglePause() {
    if (won) {
      return;
    }
    if (paused) {
      resume();
    } else {
      pause();
    }
  }

  void pause() {
    if (won || paused) {
      return;
    }
    paused = true;
    if (!isSpeed) {
      unawaited(_persistProgress());
    }
    notifyListeners();
    _restartTimer();
  }

  void resume() {
    if (!paused) {
      return;
    }
    paused = false;
    notifyListeners();
    _restartTimer();
  }

  Future<void> revealHint() async {
    if (hintsLeft <= 0) {
      return;
    }
    final remaining = placements
        .where((placement) => !placement.found)
        .toList();
    if (remaining.isEmpty) {
      return;
    }
    final placement = remaining[_random.nextInt(remaining.length)];
    hintedWords.add(placement.word);
    final cells = getPlacementCells(placement);
    hintTier = (hintsUsed % maxHints) + 1;
    hintCells = switch (hintTier) {
      1 => [cells.first],
      2 => cells.length >= 2 ? [cells.first, cells[1]] : [cells.first],
      _ => cells,
    };
    hintCell = hintCells.first;
    hintsLeft = max(0, hintsLeft - 1);
    hintsUsed += 1;
    prepaidHintsLeft = max(0, prepaidHintsLeft - 1);
    if (!isSpeed) {
      await _persistProgress();
    }
    if (_disposed) {
      return;
    }
    notifyListeners();
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2200), () {
      if (_disposed) {
        return;
      }
      hintCell = null;
      hintCells = [];
      hintTier = 0;
      notifyListeners();
    });
  }

  Future<void> refillHints() async {
    hintsLeft = maxHints;
    prepaidHintsLeft = maxHints;
    if (!isSpeed) {
      await _persistProgress();
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> markFound(WordPlacement placement) async {
    if (won || placement.found) {
      return;
    }
    final points = difficulty.wordScore * placement.word.length;
    placements = placements
        .map((candidate) {
          if (candidate.word == placement.word) {
            return candidate.copyWith(found: true);
          }
          return candidate;
        })
        .toList(growable: false);
    score += points;
    lastFound = placement;
    lastPoints = points;
    if (!isSpeed) {
      await _persistProgress();
    }
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      lastFound = null;
      lastPoints = 0;
      notifyListeners();
    });
    if (foundCount == totalCount && totalCount > 0) {
      _finish();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (won || paused) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused || won) {
        return;
      }
      elapsed += 1;
      if (isSpeed) {
        timeLeft = max(0, timeLeft - 1);
        if (timeLeft == 0) {
          _finish();
        }
      }
      if (!isSpeed && elapsed % 5 == 0) {
        unawaited(_persistProgress());
      }
      notifyListeners();
    });
  }

  void _finish() {
    if (won) {
      return;
    }
    won = true;
    _timer?.cancel();
    if (!isSpeed) {
      unawaited(_persistProgress());
    }
    onCompleted?.call();
    notifyListeners();
  }

  int _scoreForFoundWords(List<WordPlacement> placements) {
    return placements
        .where((placement) => placement.found)
        .fold(
          0,
          (sum, placement) =>
              sum + difficulty.wordScore * placement.word.length,
        );
  }

  Future<void> _persistProgress() async {
    if (isSpeed || puzzle == null) {
      return;
    }
    await _progressStore.savePuzzleProgress(
      _progressCategoryId,
      difficulty.storageName,
      SavedPuzzleProgress(
        puzzle: puzzle!,
        foundWords: placements
            .where((placement) => placement.found)
            .map((placement) => placement.word)
            .toSet(),
        score: score,
        elapsed: elapsed,
        hintsLeft: hintsLeft,
        contentVersion: puzzleContentVersion,
        hintsUsed: hintsUsed,
        hintedWords: Set<String>.unmodifiable(hintedWords),
        prepaidHintsLeft: prepaidHintsLeft,
        completed: foundCount == totalCount && totalCount > 0,
      ),
    );
  }

  bool _isCompletedProgress(SavedPuzzleProgress progress) {
    if (progress.completed) {
      return true;
    }
    if (progress.puzzle.placements.isEmpty) {
      return false;
    }
    return progress.puzzle.placements.every(
      (placement) => progress.foundWords.contains(placement.word),
    );
  }

  bool _matchesDifficultySpec(
    SavedPuzzleProgress progress,
    List<String> allowedWords,
  ) {
    final resolvedConfig = puzzleConfig ?? difficulty.puzzleConfig;
    final savedWords = progress.puzzle.placements
        .map((placement) => placement.word)
        .toSet();
    final allowedWordSet = allowedWords.toSet();
    return progress.contentVersion == puzzleContentVersion &&
        progress.puzzle.size == resolvedConfig.gridSize &&
        savedWords.length == resolvedConfig.wordCount &&
        allowedWordSet.containsAll(savedWords) &&
        progress.puzzle.placements.every(
          (placement) =>
              placement.word.length <= difficulty.gridSize &&
              isDirectionAllowedForDifficulty(
                difficulty,
                placement.dr,
                placement.dc,
                config: resolvedConfig,
              ),
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _hintTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }
}
