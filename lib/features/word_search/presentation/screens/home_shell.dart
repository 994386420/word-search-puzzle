import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../l10n/app_strings.dart';
import '../../data/daily_challenge_store.dart';
import '../../data/level_progress_store.dart';
import '../../data/local_stats_store.dart';
import '../../domain/categories.dart';
import '../../domain/kid_word_catalog.dart';
import '../../domain/level_progression.dart';
import '../../domain/models.dart';
import 'game_screen.dart';
import 'daily_challenge_screen.dart';
import 'kids_hub_screen.dart';
import 'leaderboard_screen.dart';
import 'menu_screen.dart';
import 'local_stats_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  WordCategory? _lastCategory;
  Difficulty _lastDifficulty = Difficulty.medium;
  GameMode _lastMode = GameMode.classic;
  ClueMode _lastClueMode = ClueMode.words;
  final _dailyChallengeStore = const DailyChallengeStore();
  final _levelProgressStore = const LevelProgressStore();
  final _statsStore = const LocalStatsStore();
  VoidCallback? _refreshMainMenu;
  Future<void>? _campaignProgressWrite;

  void _refreshHomeSurfaces() {
    _refreshMainMenu?.call();
  }

  void _openLeaderboardFromGame(
    BuildContext context,
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  ) {
    Navigator.of(context).push(
      _motionRoute(
        beginOffset: const Offset(0, 0.08),
        builder: (_) => LeaderboardScreen(
          initialCategory: category,
          initialDifficulty: difficulty,
          initialMode: mode,
        ),
      ),
    );
  }

  void _openNextPuzzleFromGame(
    BuildContext context,
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  ) {
    unawaited(
      _openNextPuzzleFromGameAsync(context, category, difficulty, mode),
    );
  }

  Future<void> _openNextPuzzleFromGameAsync(
    BuildContext context,
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  ) async {
    final currentIndex = wordCategories.indexWhere(
      (item) => item.id == category.id,
    );
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % wordCategories.length;
    var nextCategory = wordCategories[nextIndex];
    var nextDifficulty = difficulty;
    if (mode == GameMode.classic) {
      final stats = await _statsStore.getStats();
      if (!context.mounted) {
        return;
      }
      final recommendation = levelRecommendationForFoundWords(
        stats.totalWordsFound,
      );
      nextCategory = recommendation.category;
      nextDifficulty = recommendation.difficulty;
    }
    _lastCategory = nextCategory;
    _lastDifficulty = nextDifficulty;
    _lastMode = mode;
    Navigator.of(context)
        .pushReplacement(
          _motionRoute(
            beginOffset: const Offset(0.08, 0),
            builder: (_) => GameScreen(
              category: nextCategory,
              difficulty: nextDifficulty,
              mode: mode,
              clueMode: _lastClueMode,
              sessionLabel: _lastClueMode == ClueMode.words
                  ? null
                  : AppStrings.of(context).clueModeLabel(_lastClueMode),
              onNextPuzzle: _openNextPuzzleFromGame,
              onViewLeaderboard: _openLeaderboardFromGame,
            ),
          ),
        )
        .then((_) => _refreshHomeSurfaces());
  }

  Future<void> _openLeaderboard() async {
    final lastCategory = _lastCategory;
    final category = lastCategory;
    Difficulty difficulty;
    GameMode mode;
    WordCategory resolvedCategory;
    if (category == null) {
      final stats = await _statsStore.getStats();
      if (!mounted) {
        return;
      }
      final recommendation = levelRecommendationForFoundWords(
        stats.totalWordsFound,
      );
      resolvedCategory = recommendation.category;
      difficulty = recommendation.difficulty;
      mode = GameMode.classic;
    } else {
      resolvedCategory = category;
      difficulty = _lastDifficulty;
      mode = _lastMode;
    }
    Navigator.of(context).push(
      _motionRoute(
        beginOffset: const Offset(0, 0.08),
        builder: (_) => LeaderboardScreen(
          initialCategory: resolvedCategory,
          initialDifficulty: difficulty,
          initialMode: mode,
        ),
      ),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      _motionRoute(
        beginOffset: const Offset(0, 0.08),
        builder: (_) => const LocalStatsScreen(),
      ),
    );
  }

  Future<void> _openCurrentLevel() async {
    await Navigator.of(context).push(
      _motionRoute(
        beginOffset: const Offset(0.08, 0),
        builder: (_) => KidsHubScreen(
          onStartLevel: _openCampaignLevel,
          onStart: _openKidsGame,
        ),
      ),
    );
    _refreshHomeSurfaces();
  }

  Future<void> _continueLearning() async {
    final progress = await _levelProgressStore.load();
    if (!mounted) {
      return;
    }
    await _openCampaignLevel(progress.activeLevel);
  }

  Future<void> _openCampaignLevel(LevelDefinition level) async {
    await _levelProgressStore.setActiveLevel(level);
    if (!mounted) {
      return;
    }
    _lastCategory = level.category;
    _lastDifficulty = level.difficulty;
    _lastMode = GameMode.classic;
    _lastClueMode = level.clueMode;
    final strings = AppStrings.of(context);
    final run = await _newCampaignRun(level);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      _motionRoute(
        beginOffset: const Offset(0.08, 0),
        builder: (_) =>
            _campaignGameScreen(level, strings, run.seed, run.words),
      ),
    );
    _refreshHomeSurfaces();
  }

  Future<({int seed, List<String> words})> _newCampaignRun(
    LevelDefinition level,
  ) async {
    final seed = level.seed ^ DateTime.now().microsecondsSinceEpoch;
    final progress = await _levelProgressStore.load();
    if (!progress.results.containsKey(level.id)) {
      return (seed: seed, words: level.words);
    }
    return (
      seed: seed,
      words: selectKidWordsForRound(
        level.category.words,
        level.difficulty,
        config: level.puzzleConfig,
        random: Random(seed),
        clueMode: level.clueMode,
        categoryId: level.category.id,
        recentWords: level.words.toSet(),
      ),
    );
  }

  Widget _campaignGameScreen(
    LevelDefinition level,
    AppStrings strings,
    int runSeed,
    List<String> runWords,
  ) {
    return GameScreen(
      category: level.category,
      difficulty: level.difficulty,
      mode: GameMode.classic,
      clueMode: level.clueMode,
      progressId: level.progressId,
      randomSeed: runSeed,
      levelWords: runWords,
      levelWordPool: level.category.words,
      levelNumber: level.globalLevel,
      puzzleConfig: level.puzzleConfig,
      sessionLabel: strings.levelButton(level.globalLevel),
      onCompleted: (stars, elapsedSeconds) {
        _campaignProgressWrite = _recordCampaignCompletion(
          level,
          stars: stars,
          elapsedSeconds: elapsedSeconds,
        );
        unawaited(_campaignProgressWrite);
      },
      onNextPuzzle: (gameContext, category, difficulty, mode) {
        unawaited(_openNextCampaignLevel(gameContext, level));
      },
      onViewLeaderboard: _openLeaderboardFromGame,
    );
  }

  Future<void> _recordCampaignCompletion(
    LevelDefinition level, {
    required int stars,
    required int elapsedSeconds,
  }) async {
    await _levelProgressStore.recordCompleted(
      level,
      stars: stars,
      elapsedSeconds: elapsedSeconds,
    );
    _refreshHomeSurfaces();
  }

  Future<void> _openNextCampaignLevel(
    BuildContext gameContext,
    LevelDefinition current,
  ) async {
    await _campaignProgressWrite;
    if (!gameContext.mounted) {
      return;
    }
    final next = nextCampaignLevel(current);
    if (next == null) {
      Navigator.of(gameContext).pop();
      return;
    }
    await _levelProgressStore.setActiveLevel(next);
    if (!gameContext.mounted) {
      return;
    }
    _lastCategory = next.category;
    _lastDifficulty = next.difficulty;
    final strings = AppStrings.of(gameContext);
    final run = await _newCampaignRun(next);
    if (!gameContext.mounted) {
      return;
    }
    Navigator.of(gameContext).pushReplacement(
      _motionRoute(
        beginOffset: const Offset(0.08, 0),
        builder: (_) => _campaignGameScreen(next, strings, run.seed, run.words),
      ),
    );
  }

  void _openKidsGame(
    WordCategory category,
    Difficulty difficulty,
    ClueMode clueMode,
    GameMode gameMode,
  ) {
    _lastCategory = category;
    _lastDifficulty = difficulty;
    _lastMode = gameMode;
    _lastClueMode = clueMode;
    final strings = AppStrings.of(context);
    Navigator.of(context)
        .push(
          _motionRoute(
            beginOffset: const Offset(0.08, 0),
            builder: (_) => GameScreen(
              category: category,
              difficulty: difficulty,
              mode: gameMode,
              clueMode: clueMode,
              sessionLabel: strings.clueModeLabel(clueMode),
              onNextPuzzle: _openNextPuzzleFromGame,
              onViewLeaderboard: _openLeaderboardFromGame,
            ),
          ),
        )
        .then((_) => _refreshHomeSurfaces());
  }

  Future<void> _openDailyChallenge() async {
    final challenge = await _dailyChallengeStore.getToday();
    if (!mounted) {
      return;
    }
    final strings = AppStrings.of(context);
    _lastCategory = challenge.category;
    _lastDifficulty = challenge.difficulty;
    _lastMode = GameMode.classic;
    _lastClueMode = ClueMode.words;
    final shouldContinue = await Navigator.of(context).push<bool>(
      _motionRoute<bool>(
        beginOffset: const Offset(0, 0.08),
        builder: (_) => DailyChallengeScreen(challenge: challenge),
      ),
    );
    if (!mounted || shouldContinue != true) {
      return;
    }
    if (challenge.completedToday) {
      Navigator.of(context).push(
        _motionRoute(
          beginOffset: const Offset(0, 0.08),
          builder: (_) => LeaderboardScreen(
            initialCategory: challenge.category,
            initialDifficulty: challenge.difficulty,
            initialMode: GameMode.classic,
          ),
        ),
      );
      return;
    }
    Navigator.of(context)
        .push(
          _motionRoute(
            beginOffset: const Offset(0.08, 0),
            builder: (_) => GameScreen(
              category: challenge.category,
              difficulty: challenge.difficulty,
              mode: GameMode.classic,
              progressId: challenge.progressId,
              randomSeed: challenge.seed,
              sessionLabel: strings.daily,
              onDailyCompleted: () async {
                final streak = await _dailyChallengeStore.markCompleted();
                _refreshHomeSurfaces();
                return streak;
              },
              onViewLeaderboard: _openLeaderboardFromGame,
            ),
          ),
        )
        .then((_) => _refreshHomeSurfaces());
  }

  @override
  Widget build(BuildContext context) {
    return MainMenuScreen(
      key: const ValueKey('main-menu'),
      onContinueLearning: _continueLearning,
      onChooseThemes: _openCurrentLevel,
      onDailyChallenge: _openDailyChallenge,
      onLeaderboard: () {
        unawaited(_openLeaderboard());
      },
      onStats: _openStats,
      onRefreshReady: (refresh) => _refreshMainMenu = refresh,
    );
  }
}

PageRouteBuilder<T> _motionRoute<T>({
  required WidgetBuilder builder,
  required Offset beginOffset,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
