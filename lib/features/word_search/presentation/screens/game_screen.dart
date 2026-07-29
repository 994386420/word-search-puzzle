import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/ad_service.dart';
import '../../data/coin_store.dart';
import '../../data/feedback_service.dart';
import '../../data/leaderboard_api.dart';
import '../../data/kid_alias_store.dart';
import '../../data/local_stats_store.dart';
import '../../data/product_analytics_service.dart';
import '../../data/progress_store.dart';
import '../../data/score_submission_guard.dart';
import '../../data/voice_guide_service.dart';
import '../../data/word_review_store.dart';
import '../../domain/categories.dart';
import '../../domain/kid_word_catalog.dart';
import '../../domain/models.dart';
import '../../domain/puzzle_engine.dart';
import '../../domain/word_learning.dart';
import '../controllers/game_controller.dart';
import '../widgets/clay_ui.dart';
import '../widgets/puzzle_grid.dart';
import '../widgets/speaking_word_icon.dart';
import '../widgets/theme_scene_assets.dart';
import '../widgets/word_illustration.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.category,
    required this.difficulty,
    required this.mode,
    required this.onViewLeaderboard,
    this.progressId,
    this.randomSeed,
    this.levelWords,
    this.levelWordPool,
    this.levelNumber,
    this.puzzleConfig,
    this.sessionLabel,
    this.clueMode = ClueMode.words,
    this.showTutorial = true,
    this.onCompleted,
    this.onDailyCompleted,
    this.onNextPuzzle,
    super.key,
  });

  final WordCategory category;
  final Difficulty difficulty;
  final GameMode mode;
  final String? progressId;
  final int? randomSeed;
  final String? sessionLabel;
  final ClueMode clueMode;
  final bool showTutorial;
  final List<String>? levelWords;
  final List<String>? levelWordPool;
  final int? levelNumber;
  final PuzzleConfig? puzzleConfig;
  final void Function(int stars, int elapsedSeconds)? onCompleted;
  final Future<int> Function()? onDailyCompleted;
  final void Function(
    BuildContext context,
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  )?
  onNextPuzzle;
  final void Function(
    BuildContext context,
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  )
  onViewLeaderboard;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final _progressStore = ProgressStore();
  final _coinStore = const CoinStore();
  final _statsStore = const LocalStatsStore();
  final _wordReviewStore = const WordReviewStore();
  late final GameController _controller;
  bool _winDialogVisible = false;
  bool _showTutorial = false;
  bool _showFirstFindCelebration = false;
  bool _showCompletionCelebration = false;
  bool _seenFirstFindCelebration = true;
  bool _completionHandled = false;
  bool _winDialogScheduled = false;
  int _wrongSelectionVoiceCount = 0;
  int _comboCount = 0;
  DateTime? _lastFoundAt;
  String? _lastFeedbackWord;
  Timer? _completionCelebrationTimer;
  Timer? _winDialogTimer;
  Timer? _memoryPreviewTimer;
  bool _memoryWordsVisible = true;
  Future<int>? _dailyStreakFuture;
  Future<LocalRewardResult>? _rewardFuture;
  Future<CoinRewardResult>? _coinRewardFuture;
  int _coinBalance = CoinStore.initialBalance;
  final List<Future<void>> _wordFoundWrites = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = GameController(
      category: widget.category,
      difficulty: widget.difficulty,
      mode: widget.mode,
      clueMode: widget.clueMode,
      progressId: widget.progressId,
      randomSeed: widget.randomSeed,
      levelWords: widget.levelWords,
      levelWordPool: widget.levelWordPool,
      puzzleConfig: widget.puzzleConfig,
      onCompleted: _handleCompleted,
    )..start();
    _controller.addListener(_handleControllerChanged);
    if (widget.clueMode == ClueMode.memory) {
      _memoryPreviewTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _memoryWordsVisible = false);
        }
      });
    }
    _loadTutorialState();
    _loadFirstFindState();
    unawaited(_loadCoins());
    unawaited(AdService.instance.loadRewarded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleControllerChanged);
    _completionCelebrationTimer?.cancel();
    _winDialogTimer?.cancel();
    _memoryPreviewTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return;
    }
    _controller.pause();
    unawaited(VoiceGuideService.instance.stop());
  }

  bool get _isDailyChallenge => widget.progressId?.startsWith('daily_') == true;

  void _handleControllerChanged() {
    if (!_controller.won) {
      _resetCompletionUiIfNeeded();
      if (_controller.lastFound == null) {
        _lastFeedbackWord = null;
      }
    }
    _handleFoundFeedback();
    _showWinIfNeeded();
  }

  void _handleFoundFeedback() {
    final found = _controller.lastFound;
    if (found == null || found.word == _lastFeedbackWord) {
      return;
    }
    _lastFeedbackWord = found.word;
    final foundAt = DateTime.now();
    _comboCount =
        _lastFoundAt != null &&
            foundAt.difference(_lastFoundAt!) <= const Duration(seconds: 5)
        ? _comboCount + 1
        : 1;
    _lastFoundAt = foundAt;
    unawaited(FeedbackService.instance.wordFound());
    if (!_seenFirstFindCelebration) {
      unawaited(VoiceGuideService.instance.playFoundWord(found.word));
    } else {
      unawaited(VoiceGuideService.instance.playWord(found.word));
    }
    final wordFoundWrite = Future.wait<void>([
      _statsStore.recordWordFound(category: widget.category),
      _wordReviewStore.recordFound(
        word: found.word,
        category: widget.category,
        assisted: _controller.hintedWords.contains(found.word),
      ),
    ]).then((_) {});
    _wordFoundWrites.add(wordFoundWrite);
    unawaited(
      wordFoundWrite.whenComplete(() {
        _wordFoundWrites.remove(wordFoundWrite);
      }),
    );
    if (_showTutorial) {
      setState(() => _showTutorial = false);
      unawaited(_progressStore.markTutorialSeen());
    }
    if (!_seenFirstFindCelebration) {
      _seenFirstFindCelebration = true;
      setState(() => _showFirstFindCelebration = true);
      unawaited(_progressStore.markFirstFindCelebrationSeen());
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() => _showFirstFindCelebration = false);
        }
      });
    }
  }

  void _handleCompleted() {
    if (_completionHandled) {
      return;
    }
    _completionHandled = true;
    unawaited(
      ProductAnalyticsService.instance.record(
        'puzzle_complete',
        properties: {
          'theme': widget.category.id,
          'difficulty': widget.difficulty.storageName,
          'clue': widget.clueMode.storageName,
          'elapsed': _controller.elapsed,
          'hintsUsed': _controller.hintsUsed,
        },
      ),
    );
    unawaited(FeedbackService.instance.success());
    unawaited(
      VoiceGuideService.instance.playCue(
        _isDailyChallenge
            ? VoiceGuideCue.dailyComplete
            : VoiceGuideCue.completion,
      ),
    );
    if (mounted) {
      setState(() => _showCompletionCelebration = true);
    }
    _completionCelebrationTimer?.cancel();
    _completionCelebrationTimer = Timer(const Duration(milliseconds: 1080), () {
      if (mounted) {
        setState(() => _showCompletionCelebration = false);
      }
    });
    _rewardFuture = _recordCompletionReward();
    _coinRewardFuture = _recordCoinReward();
    unawaited(
      _coinRewardFuture!.then((result) {
        if (mounted) {
          setState(() => _coinBalance = result.balance);
        }
      }),
    );
    if (_isDailyChallenge && widget.onDailyCompleted != null) {
      _dailyStreakFuture = widget.onDailyCompleted!();
    }
    widget.onCompleted?.call(_starRating(_controller), _controller.elapsed);
  }

  void _showWinIfNeeded() {
    if (!_controller.won || _controller.paused) {
      return;
    }
    if (_winDialogVisible || _winDialogScheduled) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _winDialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.won || _winDialogVisible) {
        _winDialogScheduled = false;
        return;
      }
      _winDialogTimer?.cancel();
      _winDialogTimer = Timer(const Duration(milliseconds: 860), () {
        if (!mounted || !_controller.won || _controller.paused) {
          _winDialogScheduled = false;
          return;
        }
        if (_winDialogVisible) {
          _winDialogScheduled = false;
          return;
        }
        final route = ModalRoute.of(context);
        if (route == null || !route.isCurrent) {
          _winDialogScheduled = false;
          return;
        }
        final dailyStreakFuture = _dailyStreakFuture;
        final rewardFuture = _rewardFuture;
        _winDialogScheduled = false;
        _winDialogVisible = true;
        if (_showCompletionCelebration) {
          setState(() => _showCompletionCelebration = false);
        }
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => WinDialog(
            controller: _controller,
            onBack: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            onLeaderboard: () {
              Navigator.of(context).pop();
              widget.onViewLeaderboard(
                context,
                widget.category,
                widget.difficulty,
                widget.mode,
              );
            },
            isDailyChallenge: _isDailyChallenge,
            dailyStreakFuture: dailyStreakFuture,
            rewardFuture: rewardFuture,
            coinRewardFuture: _coinRewardFuture,
            onNextPuzzle: widget.onNextPuzzle == null
                ? null
                : (dialogContext, category, difficulty, mode) {
                    Navigator.of(dialogContext).pop();
                    widget.onNextPuzzle!(context, category, difficulty, mode);
                  },
          ),
        ).then((_) => _winDialogVisible = false);
      });
    });
  }

  void _resetCompletionUiIfNeeded() {
    if (!_completionHandled &&
        !_winDialogScheduled &&
        !_showCompletionCelebration) {
      return;
    }
    _completionCelebrationTimer?.cancel();
    _winDialogTimer?.cancel();
    _completionHandled = false;
    _winDialogScheduled = false;
    _dailyStreakFuture = null;
    _rewardFuture = null;
    _coinRewardFuture = null;
    if (_showCompletionCelebration && mounted) {
      setState(() => _showCompletionCelebration = false);
    }
  }

  Future<void> _loadTutorialState() async {
    if (!widget.showTutorial) {
      return;
    }
    final seen = await _progressStore.hasSeenTutorial();
    if (mounted && !seen) {
      setState(() => _showTutorial = true);
      unawaited(VoiceGuideService.instance.playCue(VoiceGuideCue.gameIntro));
    }
  }

  Future<void> _loadFirstFindState() async {
    final seen = await _progressStore.hasSeenFirstFindCelebration();
    if (mounted) {
      _seenFirstFindCelebration = seen;
    }
  }

  Future<void> _loadCoins() async {
    final balance = await _coinStore.getBalance();
    if (mounted) {
      setState(() => _coinBalance = balance);
    }
  }

  Future<CoinRewardResult> _recordCoinReward() {
    final progressId = widget.progressId;
    if (progressId?.startsWith('level_') == true) {
      return _coinStore.claimLevelReward(
        levelId: progressId!,
        stars: _starRating(_controller),
      );
    }
    return _coinStore.earn(
      _isDailyChallenge
          ? CoinStore.dailyChallengeReward
          : CoinStore.regularPuzzleReward,
    );
  }

  Future<void> _useHint() async {
    if (_controller.hintsLeft <= 0) {
      await _refillHints();
      return;
    }
    final cost = _currentHintCost;
    final spend = await _coinStore.spend(cost);
    if (!mounted) {
      return;
    }
    setState(() => _coinBalance = spend.balance);
    if (!spend.spent) {
      final earned = await _offerRewardedCoins(cost: cost);
      if (earned && mounted) {
        await _useHint();
      }
      return;
    }
    unawaited(
      VoiceGuideService.instance.playCue(
        VoiceGuideCue.hintUsed,
        minInterval: const Duration(seconds: 6),
        skipIfBusy: true,
      ),
    );
    await _controller.revealHint();
  }

  Future<void> _refillHints() async {
    const refillCost = 40;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      showDragHandle: false,
      builder: (context) => _HintEconomySheet(
        balance: _coinBalance,
        cost: refillCost,
        refill: true,
        canWatchVideo: AdService.instance.isSupported,
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'coins') {
      final spend = await _coinStore.spend(refillCost);
      if (!mounted) {
        return;
      }
      setState(() => _coinBalance = spend.balance);
      if (spend.spent) {
        await _controller.refillHints();
      }
      return;
    }
    if (action == 'video') {
      final earned = await AdService.instance.showRewardedUnlock();
      if (earned && mounted) {
        await _controller.refillHints();
      } else if (mounted) {
        _showRewardUnavailable();
      }
    }
  }

  Future<bool> _offerRewardedCoins({required int cost}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      showDragHandle: false,
      builder: (context) => _HintEconomySheet(
        balance: _coinBalance,
        cost: cost,
        refill: false,
        canWatchVideo: AdService.instance.isSupported,
      ),
    );
    if (!mounted || action != 'video') {
      return false;
    }
    final earned = await AdService.instance.showRewardedUnlock();
    if (!earned) {
      if (mounted) {
        _showRewardUnavailable();
      }
      return false;
    }
    final reward = await _coinStore.earn(CoinStore.rewardedVideoCoins);
    if (mounted) {
      setState(() => _coinBalance = reward.balance);
    }
    return true;
  }

  void _showRewardUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).rewardedUnavailable)),
    );
  }

  int get _currentHintCost => CoinStore.hintCost(
    _controller.hintsUsed,
    prepaidHintsLeft: _controller.prepaidHintsLeft,
  );

  Future<void> _dismissTutorial() async {
    setState(() => _showTutorial = false);
    await _progressStore.markTutorialSeen();
  }

  Future<void> _replayGuide() async {
    await _progressStore.resetGuideState();
    if (!mounted) {
      return;
    }
    setState(() {
      _showTutorial = true;
      _seenFirstFindCelebration = false;
    });
    unawaited(VoiceGuideService.instance.playCue(VoiceGuideCue.gameIntro));
  }

  void _handleWrongSelection() {
    unawaited(FeedbackService.instance.wrongSelection());
    if (_wrongSelectionVoiceCount >= 2) {
      return;
    }
    _wrongSelectionVoiceCount += 1;
    unawaited(
      VoiceGuideService.instance.playCue(
        VoiceGuideCue.tryAgain,
        minInterval: const Duration(seconds: 8),
        skipIfBusy: true,
      ),
    );
  }

  void _restartPuzzle() {
    _wrongSelectionVoiceCount = 0;
    _comboCount = 0;
    _lastFoundAt = null;
    _controller.restart();
  }

  Future<LocalRewardResult> _recordCompletionReward() async {
    if (_wordFoundWrites.isNotEmpty) {
      await Future.wait(_wordFoundWrites.toList(growable: false));
    }
    return _statsStore.recordGameCompleted(
      category: widget.category,
      mode: widget.mode,
      elapsed: _controller.elapsed,
      score: _controller.score,
      isDailyChallenge: _isDailyChallenge,
      stars: _starRating(_controller),
    );
  }

  int _starRating(GameController controller) {
    if (controller.isSpeed) {
      final ratio = controller.totalCount == 0
          ? 0.0
          : controller.foundCount / controller.totalCount;
      if (ratio >= 0.9) {
        return 3;
      }
      if (ratio >= 0.55) {
        return 2;
      }
      return 1;
    }

    final targetSeconds = switch (controller.difficulty) {
      Difficulty.easy => 120,
      Difficulty.medium => 240,
      Difficulty.hard => 420,
    };
    if (controller.hintsUsed == 0 && controller.elapsed <= targetSeconds) {
      return 3;
    }
    if (controller.hintsUsed <= 2) {
      return 2;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final palette = WordSearchPalette.of(context);
        final puzzle = _controller.puzzle;
        final boardAlignment = widget.clueMode == ClueMode.pictures
            ? Alignment.topCenter
            : const Alignment(0, -0.55);
        final timerColor = _controller.isSpeed
            ? (_controller.timeLeft < 30
                  ? const Color(0xFFEF4444)
                  : _controller.timeLeft < 60
                  ? const Color(0xFFF97316)
                  : palette.speedButtonShadow)
            : palette.classicButtonShadow;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: ClaySceneBackdrop(
                  assetPath: clayThemeSceneAsset(widget.category),
                  foregroundGradient: palette.isDark,
                  child: const SizedBox.expand(),
                ),
              ),
              if (palette.isDark)
                Positioned.fill(
                  child: ColoredBox(
                    color: palette.pageGradientColors.first.withValues(
                      alpha: 0.28,
                    ),
                  ),
                ),
              Positioned(
                left: -32,
                right: -32,
                top: MediaQuery.sizeOf(context).height * 0.43,
                height: 120,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.category.accentColor.withValues(
                        alpha: palette.isDark ? 0.1 : 0.055,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(260, 72),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                        _Header(
                          category: widget.category,
                          difficulty: widget.difficulty,
                          mode: widget.mode,
                          clueMode: widget.clueMode,
                          sessionLabel: widget.sessionLabel,
                          levelNumber: widget.levelNumber,
                          coins: _coinBalance,
                        ),
                        _WordList(
                          placements: _controller.placements,
                          category: widget.category,
                          clueMode: widget.clueMode,
                          memoryWordsVisible: _memoryWordsVisible,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                            child: puzzle == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      RepaintBoundary(
                                        child: PuzzleGrid(
                                          puzzle: puzzle,
                                          placements: _controller.placements,
                                          hintCell: _controller.hintCell,
                                          hintCells: _controller.hintCells,
                                          hintTier: _controller.hintTier,
                                          recentlyFound: _controller.lastFound,
                                          accentColor:
                                              widget.category.accentColor,
                                          alignment: boardAlignment,
                                          onWordFound: _controller.markFound,
                                          onWrongSelection:
                                              _handleWrongSelection,
                                        ),
                                      ),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        reverseDuration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          final curved = CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutBack,
                                            reverseCurve: Curves.easeInCubic,
                                          );
                                          return FadeTransition(
                                            opacity: animation,
                                            child: ScaleTransition(
                                              scale: Tween<double>(
                                                begin: 0.62,
                                                end: 1,
                                              ).animate(curved),
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0, 0.08),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            ),
                                          );
                                        },
                                        child: _controller.lastFound == null
                                            ? const SizedBox.shrink()
                                            : _FoundToast(
                                                key: ValueKey(
                                                  _controller.lastFound!.word,
                                                ),
                                                placement:
                                                    _controller.lastFound!,
                                                categoryId: widget.category.id,
                                                points: _controller.lastPoints,
                                                comboCount: _comboCount,
                                              ),
                                      ),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        reverseDuration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        child: _showFirstFindCelebration
                                            ? _FirstFindCelebration(
                                                key: const ValueKey(
                                                  'first-find',
                                                ),
                                                color:
                                                    widget.category.accentColor,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        reverseDuration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child:
                                            _showTutorial &&
                                                _controller.foundCount == 0 &&
                                                _controller
                                                    .placements
                                                    .isNotEmpty
                                            ? _BoardGestureGuide(
                                                key: const ValueKey(
                                                  'gesture-guide',
                                                ),
                                                puzzleSize: puzzle.size,
                                                placement: _controller
                                                    .placements
                                                    .firstWhere(
                                                      (placement) =>
                                                          !placement.found,
                                                      orElse: () => _controller
                                                          .placements
                                                          .first,
                                                    ),
                                                color:
                                                    widget.category.accentColor,
                                                alignment: boardAlignment,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          reverseDuration: const Duration(milliseconds: 180),
                          child: _showTutorial
                              ? _TutorialOverlay(
                                  key: const ValueKey('tutorial'),
                                  color: widget.category.accentColor,
                                  onDismiss: _dismissTutorial,
                                )
                              : const SizedBox.shrink(),
                        ),
                        _BottomBar(
                          controller: _controller,
                          timerColor: timerColor,
                          onReplayGuide: _replayGuide,
                          onHint: () => unawaited(_useHint()),
                          onRestart: _restartPuzzle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                reverseDuration: const Duration(milliseconds: 160),
                child: _controller.paused
                    ? _PauseOverlay(
                        key: const ValueKey('pause'),
                        onResume: _controller.resume,
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  reverseDuration: const Duration(milliseconds: 180),
                  child: _showCompletionCelebration
                      ? _CompletionCelebration(
                          key: const ValueKey('completion-celebration'),
                          controller: _controller,
                          color: widget.category.accentColor,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.difficulty,
    required this.mode,
    required this.clueMode,
    required this.sessionLabel,
    required this.levelNumber,
    required this.coins,
  });

  final WordCategory category;
  final Difficulty difficulty;
  final GameMode mode;
  final ClueMode clueMode;
  final String? sessionLabel;
  final int? levelNumber;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final title = clueMode == ClueMode.pictures
        ? strings.pictureModeTitle
        : strings.findWordsTitle;
    final subtitle = levelNumber == null
        ? '${strings.categoryName(category.id)} · ${strings.difficultyLabel(difficulty)}'
        : '${strings.levelButton(levelNumber!)} · ${strings.categoryName(category.id)} · ${strings.difficultyLabel(difficulty)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
      child: SizedBox(
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: ClayPressable(
                onTap: () => Navigator.of(context).pop(),
                semanticLabel: MaterialLocalizations.of(
                  context,
                ).backButtonTooltip,
                color: palette.headerButtonBackground,
                shadowColor: palette.headerButtonBorder,
                radius: 18,
                padding: EdgeInsets.zero,
                child: SizedBox.square(
                  dimension: 38,
                  child: Icon(
                    Icons.arrow_back,
                    size: 21,
                    color: palette.headerButtonForeground,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              left: 60,
              right: 82,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClayWorldTitle(title, fontSize: 22, maxLines: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.mutedColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(right: 0, child: _HeaderCoinPill(balance: coins)),
          ],
        ),
      ),
    );
  }
}

class _HeaderCoinPill extends StatelessWidget {
  const _HeaderCoinPill({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(balance),
      tween: Tween(begin: balance == 0 ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final pulse = balance == 0 ? 0.0 : math.sin(value * math.pi);
        return Transform.scale(
          scale: 1 + pulse * 0.12,
          child: CustomPaint(
            painter: _CoinSparkPainter(progress: value, active: balance > 0),
            child: Container(
              height: 38,
              padding: const EdgeInsets.only(left: 14, right: 3),
              decoration: BoxDecoration(
                color: palette.headerButtonBackground,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: palette.headerButtonBorder),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFFC928,
                    ).withValues(alpha: 0.16 + pulse * 0.18),
                    blurRadius: 12 + pulse * 12,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$balance',
                    style: TextStyle(
                      color: palette.headerButtonForeground,
                      fontSize: 16 + pulse * 1.5,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Color(0x55000000), blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC928),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF7C5A00,
                          ).withValues(alpha: 0.28),
                          blurRadius: 9,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: pulse * 0.18,
                      child: const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFFFF7B0),
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoinSparkPainter extends CustomPainter {
  const _CoinSparkPainter({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) {
      return;
    }
    final eased = Curves.easeOutCubic.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(size.width - 18, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFFFD34D).withValues(alpha: opacity * 0.78)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = 21 + eased * 5;
      final outer = 28 + eased * 10;
      canvas.drawLine(
        center.translate(math.cos(angle) * inner, math.sin(angle) * inner),
        center.translate(math.cos(angle) * outer, math.sin(angle) * outer),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoinSparkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.active != active;
  }
}

class _WordProgressBadge extends StatelessWidget {
  const _WordProgressBadge({
    required this.found,
    required this.total,
    required this.remaining,
    required this.color,
  });

  final int found;
  final int total;
  final int remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(found),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final pulse = found == 0 ? 0.0 : math.sin(value * math.pi);
        return Transform.scale(scale: 1 + pulse * 0.08, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: palette.headerButtonBackground.withValues(
            alpha: palette.isDark ? 0.22 : 0.34,
          ),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: palette.headerButtonBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              remaining == 0 ? Icons.check_circle : Icons.search_rounded,
              size: 13,
              color: palette.titleColor.withValues(alpha: 0.82),
            ),
            const SizedBox(width: 4),
            Text(
              '${strings.found} $found/$total',
              style: TextStyle(
                color: palette.titleColor.withValues(alpha: 0.86),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordProgressStrip extends StatelessWidget {
  const _WordProgressStrip({
    required this.progress,
    required this.color,
    required this.highlighted,
  });

  final double progress;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      height: 7,
      color: palette.headerButtonBackground.withValues(
        alpha: palette.isDark ? 0.18 : 0.28,
      ),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.82),
                    palette.hintColor.withValues(alpha: 0.92),
                  ],
                ),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: palette.hintColor.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

const _pictureClueSpacing = 6.0;
const _pictureClueRunSpacing = 8.0;
const _pictureClueHorizontalPadding = 6.0;
const _pictureClueVerticalPadding = 6.0;
const _pictureClueTopPadding = 9.0;
const _pictureClueBottomPadding = 10.0;
const _pictureClueViewportHorizontalInsets = 50.0;

({int columns, int rows, double pictureSize, double contentHeight})
calculatePictureClueGridLayout({
  required double availableWidth,
  required int itemCount,
}) {
  if (itemCount <= 0) {
    return (
      columns: 1,
      rows: 0,
      pictureSize: 58,
      contentHeight: _pictureClueTopPadding + _pictureClueBottomPadding,
    );
  }
  const minimumReadableSize = 44.0;
  final useHeroPictureGrid = itemCount <= 4;
  final maximumPictureSize = useHeroPictureGrid ? 92.0 : 58.0;
  final idealColumns = useHeroPictureGrid
      ? math.min(2, itemCount)
      : itemCount <= 6
      ? itemCount
      : (itemCount + 1) ~/ 2;
  final maxColumnsAtReadableSize = math.max(
    1,
    ((availableWidth + _pictureClueSpacing) /
            (minimumReadableSize +
                _pictureClueHorizontalPadding +
                _pictureClueSpacing))
        .floor(),
  );
  final columns = math.max(1, math.min(idealColumns, maxColumnsAtReadableSize));
  final rawPictureSize =
      (availableWidth - _pictureClueSpacing * (columns - 1)) / columns -
      _pictureClueHorizontalPadding;
  final pictureSize = rawPictureSize.clamp(36.0, maximumPictureSize);
  final rows = (itemCount + columns - 1) ~/ columns;
  final contentHeight =
      _pictureClueTopPadding +
      _pictureClueBottomPadding +
      rows * (pictureSize + _pictureClueVerticalPadding) +
      math.max(0, rows - 1) * _pictureClueRunSpacing;
  return (
    columns: columns,
    rows: rows,
    pictureSize: pictureSize,
    contentHeight: contentHeight,
  );
}

class _WordList extends StatelessWidget {
  const _WordList({
    required this.placements,
    required this.category,
    required this.clueMode,
    required this.memoryWordsVisible,
  });

  final List<WordPlacement> placements;
  final WordCategory category;
  final ClueMode clueMode;
  final bool memoryWordsVisible;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final total = placements.length;
    final found = placements.where((placement) => placement.found).length;
    final remaining = math.max(0, total - found);
    final progress = total == 0 ? 0.0 : found / total;
    final nearlyDone = total > 0 && remaining <= 2 && found > 0;
    if (clueMode == ClueMode.pictures) {
      return _PictureCluePanel(
        placements: placements,
        category: category,
        found: found,
        remaining: remaining,
        progress: progress,
      );
    }
    final availablePictureWidth = math.max(
      0.0,
      math.min(MediaQuery.sizeOf(context).width, 430.0) -
          _pictureClueViewportHorizontalInsets,
    );
    final pictureLayout = calculatePictureClueGridLayout(
      availableWidth: availablePictureWidth,
      itemCount: total,
    );
    return ClaySurface(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      padding: EdgeInsets.zero,
      radius: 20,
      accentColor: category.accentColor,
      backgroundColor: palette.wordListSurface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            decoration: BoxDecoration(
              color: category.accentColor,
              boxShadow: [
                BoxShadow(
                  color: category.accentColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.categoryName(category.id),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.titleColor.withValues(alpha: 0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Color(0x33FFFFFF), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _WordProgressBadge(
                  found: found,
                  total: total,
                  remaining: remaining,
                  color: category.accentColor,
                ),
              ],
            ),
          ),
          _WordProgressStrip(
            progress: progress,
            color: category.accentColor,
            highlighted: nearlyDone,
          ),
          if (nearlyDone)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 5, bottom: 1),
              color: palette.headerButtonBackground.withValues(alpha: 0.18),
              child: Text(
                strings.wordsLeft(remaining),
                style: TextStyle(
                  color: category.accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: clueMode == ClueMode.pictures
                  ? pictureLayout.contentHeight
                  : 88,
            ),
            child: SingleChildScrollView(
              physics: clueMode == ClueMode.pictures
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: EdgeInsets.fromLTRB(
                10,
                clueMode == ClueMode.pictures ? _pictureClueTopPadding : 7,
                10,
                clueMode == ClueMode.pictures ? _pictureClueBottomPadding : 8,
              ),
              child: Align(
                alignment: clueMode == ClueMode.pictures
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: Wrap(
                  alignment: clueMode == ClueMode.pictures
                      ? WrapAlignment.center
                      : WrapAlignment.start,
                  spacing: clueMode == ClueMode.pictures
                      ? _pictureClueSpacing
                      : 7,
                  runSpacing: clueMode == ClueMode.pictures
                      ? _pictureClueRunSpacing
                      : 3,
                  children: placements
                      .map((placement) {
                        final chip = AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: clueMode == ClueMode.pictures ? 3 : 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: placement.found
                                ? placement.color.withValues(alpha: 0.22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              clueMode == ClueMode.pictures ? 13 : 99,
                            ),
                            border: placement.found
                                ? Border.all(
                                    color: placement.color.withValues(
                                      alpha: 0.46,
                                    ),
                                  )
                                : null,
                            boxShadow: placement.found
                                ? [
                                    BoxShadow(
                                      color: placement.color.withValues(
                                        alpha: 0.14,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (placement.found &&
                                  clueMode != ClueMode.pictures) ...[
                                Icon(
                                  Icons.check_circle,
                                  color: placement.color,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                              ],
                              _ClueContent(
                                placement: placement,
                                categoryId: category.id,
                                clueMode: clueMode,
                                memoryWordsVisible: memoryWordsVisible,
                                textColor: placement.found
                                    ? palette.boardLetterColor
                                    : palette.boardMutedLetterColor,
                                pictureSize: pictureLayout.pictureSize,
                              ),
                              if (placement.found &&
                                  clueMode != ClueMode.pictures) ...[
                                const SizedBox(width: 4),
                                SpeakingWordIcon(
                                  word: placement.word,
                                  color: placement.color,
                                  size: 12,
                                ),
                              ],
                            ],
                          ),
                        );
                        final canPlayAudio =
                            placement.found || clueMode == ClueMode.sounds;
                        if (!canPlayAudio) {
                          return chip;
                        }
                        return Semantics(
                          button: true,
                          label: strings.playWordAudio(placement.word),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              unawaited(
                                VoiceGuideService.instance.playWord(
                                  placement.word,
                                ),
                              );
                            },
                            child: chip,
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PictureCluePanel extends StatelessWidget {
  const _PictureCluePanel({
    required this.placements,
    required this.category,
    required this.found,
    required this.remaining,
    required this.progress,
  });

  final List<WordPlacement> placements;
  final WordCategory category;
  final int found;
  final int remaining;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final featured = placements.isEmpty
        ? null
        : placements.firstWhere(
            (placement) => !placement.found,
            orElse: () => placements.first,
          );
    final supporting = featured == null
        ? const <WordPlacement>[]
        : placements
              .where((placement) => placement.word != featured.word)
              .toList(growable: false);
    return ClaySurface(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      padding: EdgeInsets.zero,
      radius: 22,
      accentColor: category.accentColor,
      backgroundColor: palette.wordListSurface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            color: category.accentColor,
            child: Row(
              children: [
                const Icon(
                  Icons.image_rounded,
                  color: ClayWorldColors.creamHighlight,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    strings.categoryName(category.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ClayWorldColors.creamHighlight,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _WordProgressBadge(
                  found: found,
                  total: placements.length,
                  remaining: remaining,
                  color: category.accentColor,
                ),
              ],
            ),
          ),
          _WordProgressStrip(
            progress: progress,
            color: category.accentColor,
            highlighted: remaining <= 2 && found > 0,
          ),
          if (featured != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PictureClueTile(
                    placement: featured,
                    categoryId: category.id,
                    size: 116,
                    featured: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: supporting
                          .map(
                            (placement) => _PictureClueTile(
                              placement: placement,
                              categoryId: category.id,
                              size: 54,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PictureClueTile extends StatelessWidget {
  const _PictureClueTile({
    required this.placement,
    required this.categoryId,
    required this.size,
    this.featured = false,
  });

  final WordPlacement placement;
  final String categoryId;
  final double size;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final radius = featured ? 24.0 : 15.0;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      padding: EdgeInsets.all(featured ? 4 : 2.5),
      decoration: BoxDecoration(
        color: ClayWorldColors.creamHighlight,
        borderRadius: BorderRadius.circular(radius + 4),
        border: Border.all(
          color: placement.found
              ? placement.color
              : featured
              ? ClayWorldColors.deepPurple
              : ClayWorldColors.creamEdge,
          width: featured ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (featured ? ClayWorldColors.deepPurpleShadow : placement.color)
                    .withValues(alpha: featured ? 0.28 : 0.16),
            blurRadius: featured ? 12 : 5,
            offset: Offset(0, featured ? 6 : 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            WordIllustration(
              word: placement.word,
              categoryId: categoryId,
              width: size,
              height: size,
              borderRadius: radius,
            ),
            if (placement.found)
              Positioned(
                top: featured ? 6 : 3,
                right: featured ? 6 : 3,
                child: Container(
                  width: featured ? 25 : 18,
                  height: featured ? 25 : 18,
                  decoration: BoxDecoration(
                    color: placement.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: featured ? 17 : 12,
                  ),
                ),
              ),
            if (placement.found)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: featured ? 23 : 16,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  color: Colors.black.withValues(alpha: 0.62),
                  child: Text(
                    placement.word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: featured ? 10 : 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!placement.found) {
      return tile;
    }
    return Semantics(
      button: true,
      label: AppStrings.of(context).playWordAudio(placement.word),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          unawaited(VoiceGuideService.instance.playWord(placement.word));
        },
        child: tile,
      ),
    );
  }
}

class _ClueContent extends StatelessWidget {
  const _ClueContent({
    required this.placement,
    required this.categoryId,
    required this.clueMode,
    required this.memoryWordsVisible,
    required this.textColor,
    this.pictureSize = 58,
  });

  final WordPlacement placement;
  final String categoryId;
  final ClueMode clueMode;
  final bool memoryWordsVisible;
  final Color textColor;
  final double pictureSize;

  @override
  Widget build(BuildContext context) {
    if (clueMode == ClueMode.pictures) {
      final pictureRadius = (pictureSize * 0.18).clamp(8.0, 10.0);
      final badgeSize = (pictureSize * 0.31).clamp(14.0, 18.0);
      final badgeIconSize = (badgeSize * 0.67).clamp(10.0, 12.0);
      final labelHeight = (pictureSize * 0.31).clamp(15.0, 18.0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(pictureRadius),
        child: SizedBox(
          width: pictureSize,
          height: pictureSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              WordIllustration(
                word: placement.word,
                categoryId: categoryId,
                width: pictureSize,
                height: pictureSize,
                borderRadius: pictureRadius,
              ),
              if (placement.found) ...[
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: placement.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: badgeIconSize,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: labelHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.black.withValues(alpha: 0.62),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            placement.word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final showWord =
        placement.found ||
        clueMode == ClueMode.words ||
        (clueMode == ClueMode.memory && memoryWordsVisible);
    if (showWord) {
      return AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 180),
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        child: Text(placement.word),
      );
    }
    if (clueMode == ClueMode.sounds) {
      return Icon(Icons.volume_up_rounded, color: textColor, size: 20);
    }
    return Icon(Icons.visibility_off_rounded, color: textColor, size: 18);
  }
}

class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay({
    required this.color,
    required this.onDismiss,
    super.key,
  });

  final Color color;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 24),
                child: Transform.scale(
                  scale: 0.94 + value * 0.06,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            key: const ValueKey('tutorial-card'),
            constraints: const BoxConstraints(maxWidth: 338),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: palette.sheetSurface.withValues(
                alpha: palette.isDark ? 0.94 : 0.9,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _TutorialPathPreview(color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.traceAWord,
                        style: TextStyle(
                          color: palette.titleColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        strings.dragAcrossLetters,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: onDismiss,
                  tooltip: strings.gotIt,
                  style: IconButton.styleFrom(
                    backgroundColor: color,
                    fixedSize: const Size(40, 40),
                  ),
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardGestureGuide extends StatefulWidget {
  const _BoardGestureGuide({
    required this.puzzleSize,
    required this.placement,
    required this.color,
    required this.alignment,
    super.key,
  });

  final int puzzleSize;
  final WordPlacement placement;
  final Color color;
  final Alignment alignment;

  @override
  State<_BoardGestureGuide> createState() => _BoardGestureGuideState();
}

class _BoardGestureGuideState extends State<_BoardGestureGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return Align(
            alignment: widget.alignment,
            child: SizedBox(
              key: const ValueKey('gesture-guide-board'),
              width: side,
              height: side,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _BoardGesturePainter(
                      puzzleSize: widget.puzzleSize,
                      placement: widget.placement,
                      color: widget.color,
                      progress: _motion.value,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardGesturePainter extends CustomPainter {
  const _BoardGesturePainter({
    required this.puzzleSize,
    required this.placement,
    required this.color,
    required this.progress,
  });

  final int puzzleSize;
  final WordPlacement placement;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / puzzleSize;
    final start = Offset(
      (placement.startCol + 0.5) * cell,
      (placement.startRow + 0.5) * cell,
    );
    final end = Offset(
      (placement.startCol + placement.dc * (placement.word.length - 1) + 0.5) *
          cell,
      (placement.startRow + placement.dr * (placement.word.length - 1) + 0.5) *
          cell,
    );
    final drawPhase = (progress / 0.72).clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(drawPhase);
    final current = Offset.lerp(start, end, eased)!;
    final fade = progress > 0.78
        ? (1 - ((progress - 0.78) / 0.22)).clamp(0.0, 1.0)
        : 1.0;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.22 * fade)
      ..strokeWidth = cell * 0.72
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final pathPaint = Paint()
      ..color = color.withValues(alpha: 0.68 * fade)
      ..strokeWidth = cell * 0.48
      ..strokeCap = StrokeCap.round;
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.54 * fade)
      ..strokeWidth = cell * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, current, glowPaint);
    canvas.drawLine(start, current, pathPaint);
    canvas.drawLine(start, current, shinePaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.white.withValues(alpha: 0.42 * fade);
    for (final point in [start, end]) {
      canvas.drawCircle(
        point,
        cell * (0.42 + math.sin(progress * math.pi) * 0.08),
        ringPaint,
      );
    }

    final fingerLift = math.sin(progress * math.pi * 2).clamp(-0.4, 1.0);
    final fingerCenter = current.translate(
      cell * 0.16,
      cell * (0.22 - fingerLift * 0.05),
    );
    final fingerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.14 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(
      fingerCenter.translate(0, cell * 0.08),
      cell * 0.18,
      fingerShadow,
    );
    canvas.drawCircle(
      fingerCenter,
      cell * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.92 * fade),
    );
    canvas.drawCircle(
      fingerCenter,
      cell * 0.08,
      Paint()..color = color.withValues(alpha: 0.9 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardGesturePainter oldDelegate) {
    return oldDelegate.puzzleSize != puzzleSize ||
        oldDelegate.placement != placement ||
        oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}

class _FirstFindCelebration extends StatelessWidget {
  const _FirstFindCelebration({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - value) * -18),
                child: Transform.scale(
                  scale: 0.92 + value * 0.08,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
            decoration: BoxDecoration(
              color: palette.sheetSurface.withValues(
                alpha: palette.isDark ? 0.94 : 0.92,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  strings.greatFirstFind,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialPathPreview extends StatefulWidget {
  const _TutorialPathPreview({required this.color});

  final Color color;

  @override
  State<_TutorialPathPreview> createState() => _TutorialPathPreviewState();
}

class _TutorialPathPreviewState extends State<_TutorialPathPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _TutorialPathPainter(
            widget.color,
            Curves.easeInOutCubic.transform(_controller.value),
          ),
        );
      },
    );
  }
}

class _TutorialPathPainter extends CustomPainter {
  const _TutorialPathPainter(this.color, this.progress);

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final letterPaint = Paint()
      ..color = const Color(0xFF0F766E).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final selectedPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    final centers = [
      Offset(size.width * 0.22, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.78, size.height * 0.5),
    ];
    final animatedEnd = Offset.lerp(centers.first, centers.last, progress)!;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(centers.first, animatedEnd, glowPaint);
    canvas.drawLine(centers.first, animatedEnd, linePaint);
    for (var i = 0; i < centers.length; i++) {
      final reached = progress >= i / (centers.length - 1);
      canvas.drawCircle(
        centers[i],
        reached ? 12 : 11,
        reached ? selectedPaint : letterPaint,
      );
      textPainter.text = TextSpan(
        text: ['C', 'A', 'T'][i],
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        centers[i] - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
    canvas.drawCircle(
      animatedEnd,
      5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.86)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialPathPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.timerColor,
    required this.onReplayGuide,
    required this.onHint,
    required this.onRestart,
  });

  final GameController controller;
  final Color timerColor;
  final VoidCallback onReplayGuide;
  final VoidCallback onHint;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final category = controller.category;
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final hintCost = CoinStore.hintCost(
      controller.hintsUsed,
      prepaidHintsLeft: controller.prepaidHintsLeft,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 5, 14, 8),
        child: ClaySurface(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          radius: 24,
          accentColor: category.accentColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ToolButton(
                icon: Icons.lightbulb,
                semanticLabel: strings.useHint,
                label: controller.hintsLeft > 0
                    ? '${controller.hintsLeft}·${hintCost == 0 ? strings.free : hintCost}'
                    : '+',
                color: controller.hintsLeft > 0
                    ? const Color(0xFFFFD34D)
                    : palette.mutedColor,
                pulse: controller.hintCell != null,
                onTap: onHint,
              ),
              const SizedBox(width: 12),
              _ToolButton(
                icon: Icons.volume_up_rounded,
                semanticLabel: strings.replayGuide,
                color: palette.isDark
                    ? palette.pageForegroundColor
                    : palette.headerButtonForeground,
                onTap: onReplayGuide,
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _CountdownText(
                    seconds: controller.isSpeed
                        ? controller.timeLeft
                        : controller.elapsed,
                    color: timerColor,
                    urgent: controller.isSpeed && controller.timeLeft <= 10,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _ToolButton(
                icon: Icons.pause,
                semanticLabel: strings.pauseGame,
                color: controller.paused
                    ? category.accentColor
                    : palette.isDark
                    ? palette.pageForegroundColor
                    : palette.headerButtonForeground,
                onTap: controller.togglePause,
              ),
              _ToolButton(
                icon: Icons.refresh_rounded,
                semanticLabel: strings.restartPuzzle,
                color: palette.isDark
                    ? palette.pageForegroundColor
                    : palette.headerButtonForeground,
                onTap: onRestart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.label,
    this.pulse = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String semanticLabel;
  final String? label;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(pulse),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final pulseScale = pulse ? 1 + math.sin(value * math.pi) * 0.13 : 1.0;
        return Transform.scale(scale: pulseScale, child: child);
      },
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: ClayPressable(
          onTap: onTap,
          semanticLabel: semanticLabel,
          color: palette.iconSurface.withValues(
            alpha: onTap == null ? 0.62 : 1,
          ),
          shadowColor: onTap == null
              ? palette.tileBorder
              : Color.alphaBlend(
                  color.withValues(alpha: 0.28),
                  palette.titleColor,
                ),
          radius: 21,
          padding: EdgeInsets.zero,
          child: SizedBox.square(
            dimension: 42,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 23, color: color),
                if (label != null)
                  Positioned(
                    right: -10,
                    bottom: -11,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: onTap == null
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFFFFD166),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Text(
                        label!,
                        style: TextStyle(
                          color: onTap == null
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF5F3B00),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownText extends StatelessWidget {
  const _CountdownText({
    required this.seconds,
    required this.color,
    required this.urgent,
    required this.style,
  });

  final int seconds;
  final Color color;
  final bool urgent;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(seconds),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final pulse = urgent ? math.sin(value * math.pi) : 0.0;
        return Transform.scale(
          scale: 1 + pulse * 0.16,
          child: Text(
            formatSeconds(seconds),
            style: style.copyWith(
              color: Color.lerp(color, const Color(0xFFFFFFFF), pulse * 0.35),
              shadows: urgent
                  ? [
                      Shadow(
                        color: const Color(
                          0xFFEF4444,
                        ).withValues(alpha: 0.55 + pulse * 0.25),
                        blurRadius: 10 + pulse * 10,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _FoundToast extends StatelessWidget {
  const _FoundToast({
    required this.placement,
    required this.categoryId,
    required this.points,
    required this.comboCount,
    super.key,
  });

  final WordPlacement placement;
  final String categoryId;
  final int points;
  final int comboCount;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final learning = wordLearningEntryFor(placement.word);
    final palette = WordSearchPalette.of(context);
    final hasVisual =
        kidWordVisualAssetFor(placement.word, categoryId: categoryId) != null;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: Transform.scale(
              scale: 0.92 + value * 0.08,
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 332),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: palette.sheetSurface.withValues(
              alpha: palette.isDark ? 0.96 : 0.94,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: placement.color.withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasVisual) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: placement.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: placement.color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: WordIllustration(
                        key: ValueKey('found-word-image-${placement.word}'),
                        word: placement.word,
                        categoryId: categoryId,
                        width: 48,
                        height: 48,
                        borderRadius: 10,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: placement.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.learnedWord,
                      style: TextStyle(
                        color: palette.mutedColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      placement.word,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: placement.color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      learning.meaningFor(strings.locale.languageCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PointsBurstPill(points: points),
                  if (comboCount >= 2) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: placement.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        strings.combo(comboCount),
                        style: TextStyle(
                          color: placement.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsBurstPill extends StatelessWidget {
  const _PointsBurstPill({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: 0.86 + value * 0.14, child: child);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 9, 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD34D),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB020).withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on,
              color: Color(0xFFFFF7B0),
              size: 15,
            ),
            const SizedBox(width: 3),
            Text(
              strings.points(points),
              style: const TextStyle(
                color: Color(0xFF5F3B00),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionCelebration extends StatefulWidget {
  const _CompletionCelebration({
    required this.controller,
    required this.color,
    super.key,
  });

  final GameController controller;
  final Color color;

  @override
  State<_CompletionCelebration> createState() => _CompletionCelebrationState();
}

class _CompletionCelebrationState extends State<_CompletionCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1080),
    )..forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final controller = widget.controller;
    final isPartialSpeedRun =
        controller.isSpeed && controller.foundCount < controller.totalCount;
    final title = controller.isSpeed
        ? (isPartialSpeedRun ? strings.timesUp : strings.perfect)
        : strings.puzzleSolved;
    final icon = isPartialSpeedRun
        ? Icons.timer_rounded
        : Icons.emoji_events_rounded;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          final value = _motion.value;
          final intro = Curves.easeOutBack.transform(
            (value / 0.48).clamp(0.0, 1.0),
          );
          final glow = math.sin(value * math.pi).clamp(0.0, 1.0);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05 * glow),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CompletionBurstPainter(
                      progress: value,
                      color: widget.color,
                      warm: palette.hintColor,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, (1 - intro) * 26),
                  child: Transform.scale(
                    scale: 0.72 + intro * 0.28 + glow * 0.025,
                    child: Opacity(
                      opacity: intro.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 304),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.celebrationSurfaceStart,
                palette.celebrationSurfaceEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.34),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.34),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: palette.hintColor.withValues(alpha: 0.48),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(
                      color: widget.color.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.categoryProgressSummary(
                  categoryId: controller.category.id,
                  found: controller.foundCount,
                  total: controller.totalCount,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompletionMetricPill(
                    label: strings.found,
                    value: '${controller.foundCount}/${controller.totalCount}',
                    color: widget.color,
                  ),
                  const SizedBox(width: 8),
                  _CompletionMetricPill(
                    label: strings.score,
                    value: '${controller.score}',
                    color: const Color(0xFFFFB020),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionMetricPill extends StatelessWidget {
  const _CompletionMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.84),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: palette.titleColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBurstPainter extends CustomPainter {
  const _CompletionBurstPainter({
    required this.progress,
    required this.color,
    required this.warm,
  });

  final double progress;
  final Color color;
  final Color warm;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 16);
    final maxRadius = math.min(size.width, size.height) * 0.44;
    final burst = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final fade =
        (1 -
                Curves.easeIn.transform(
                  ((progress - 0.62) / 0.38).clamp(0.0, 1.0),
                ))
            .clamp(0.0, 1.0);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = warm.withValues(alpha: 0.32 * fade);
    canvas.drawCircle(center, 54 + burst * 48, ringPaint);
    canvas.drawCircle(
      center,
      76 + burst * 72,
      ringPaint..color = color.withValues(alpha: 0.2 * fade),
    );

    for (var i = 0; i < 26; i++) {
      final angle = (i / 26) * math.pi * 2 + (i.isEven ? 0.16 : -0.11);
      final lane = i % 3;
      final radius = 54 + burst * (maxRadius - lane * 20);
      final point = center.translate(
        math.cos(angle) * radius,
        math.sin(angle) * radius * 0.82,
      );
      final paint = Paint()
        ..color = (i % 2 == 0 ? color : warm).withValues(
          alpha: (0.28 + lane * 0.13) * fade,
        )
        ..style = PaintingStyle.fill;
      final sizeBase = 4.0 + lane * 1.8;
      if (i % 4 == 0) {
        final sparklePaint = Paint()
          ..color = warm.withValues(alpha: 0.72 * fade)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          point.translate(-sizeBase, 0),
          point.translate(sizeBase, 0),
          sparklePaint,
        );
        canvas.drawLine(
          point.translate(0, -sizeBase),
          point.translate(0, sizeBase),
          sparklePaint,
        );
      } else {
        canvas.drawCircle(point, sizeBase, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CompletionBurstPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.warm != warm;
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, super.key});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Positioned.fill(
      child: Container(
        color: Color.alphaBlend(
          palette.pageGradientColors.first.withValues(alpha: 0.2),
          Colors.black.withValues(alpha: 0.62),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.88, end: 1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: SizedBox(
              width: 286,
              child: ClaySurface(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                radius: 26,
                accentColor: palette.classicButtonColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClayIconBadge(
                      icon: Icons.pause_rounded,
                      color: palette.classicButtonColor,
                      size: 62,
                      iconSize: 34,
                    ),
                    const SizedBox(height: 13),
                    Text(
                      strings.paused,
                      style: TextStyle(
                        color: palette.titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onResume,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.classicButtonColor,
                        foregroundColor: palette.headerButtonForeground,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(strings.resume),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _winDialogError = Color(0xFFE05252);

class _HintEconomySheet extends StatelessWidget {
  const _HintEconomySheet({
    required this.balance,
    required this.cost,
    required this.refill,
    required this.canWatchVideo,
  });

  final int balance;
  final int cost;
  final bool refill;
  final bool canWatchVideo;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ClaySurface(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
            radius: 26,
            accentColor: palette.hintColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.tileBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 15),
                ClayIconBadge(
                  icon: refill
                      ? Icons.lightbulb_rounded
                      : Icons.monetization_on_rounded,
                  color: palette.hintColor,
                  size: 56,
                  iconSize: 29,
                ),
                const SizedBox(height: 12),
                Text(
                  refill ? strings.hintsRefill : strings.notEnoughCoins,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  refill
                      ? strings.hintRefillBody(GameController.maxHints)
                      : strings.coinShortageBody(cost, balance),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.mutedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                if (refill && balance >= cost) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop('coins'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.levelButtonColor,
                        foregroundColor: palette.isDark
                            ? palette.headerButtonForeground
                            : palette.titleColor,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.monetization_on_rounded),
                      label: Text(strings.spendCoins(cost)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (canWatchVideo) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop('video'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.speedButtonColor,
                        backgroundColor: palette.tileSurface,
                        side: BorderSide(color: palette.tileBorder),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: Text(
                        refill ? strings.watchForHints : strings.watchForCoins,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.mutedColor,
                  ),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WinDialog extends StatefulWidget {
  const WinDialog({
    required this.controller,
    required this.onBack,
    required this.onLeaderboard,
    required this.isDailyChallenge,
    this.onNextPuzzle,
    this.dailyStreakFuture,
    this.rewardFuture,
    this.coinRewardFuture,
    super.key,
  });

  final GameController controller;
  final VoidCallback onBack;
  final VoidCallback onLeaderboard;
  final bool isDailyChallenge;
  final void Function(
    BuildContext context,
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  )?
  onNextPuzzle;
  final Future<int>? dailyStreakFuture;
  final Future<LocalRewardResult>? rewardFuture;
  final Future<CoinRewardResult>? coinRewardFuture;

  @override
  State<WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<WinDialog> {
  final _api = LeaderboardApi();
  final _submissionGuard = ScoreSubmissionGuard();
  final _aliasStore = KidAliasStore();
  late final Future<String> _aliasFuture = _aliasStore.getOrCreate();
  String _state = 'idle';
  String? _errorMessage;
  int? _rank;
  bool _showScoreSubmission = false;
  bool _showRoundDetails = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.registerGameCompleted();
  }

  Future<void> _submit() async {
    if (_state == 'submitting') {
      return;
    }
    setState(() {
      _state = 'submitting';
      _errorMessage = null;
    });
    try {
      final name = await _aliasFuture;
      final submission = await _submissionGuard.prepare(
        category: widget.controller.category,
        difficulty: widget.controller.difficulty,
        mode: widget.controller.mode,
        name: name,
        time: widget.controller.elapsed,
        score: widget.controller.score,
        maxScore: widget.controller.maxScore,
      );
      final result = await _api.submitScore(
        categoryId: widget.controller.category.id,
        difficulty: widget.controller.difficulty.storageName,
        mode: widget.controller.mode.storageName,
        name: submission.name,
        time: submission.time,
        score: submission.score,
      );
      await _submissionGuard.markSubmitted(
        category: widget.controller.category,
        difficulty: widget.controller.difficulty,
        mode: widget.controller.mode,
      );
      if (mounted) {
        setState(() {
          _rank = result.rank;
          _state = 'done';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _state = 'error';
          _errorMessage = error.toString();
        });
      }
    }
  }

  int _starRating(GameController controller) {
    if (controller.isSpeed) {
      final ratio = controller.totalCount == 0
          ? 0.0
          : controller.foundCount / controller.totalCount;
      if (ratio >= 0.9) {
        return 3;
      }
      if (ratio >= 0.55) {
        return 2;
      }
      return 1;
    }

    final targetSeconds = switch (controller.difficulty) {
      Difficulty.easy => 120,
      Difficulty.medium => 240,
      Difficulty.hard => 420,
    };
    if (controller.hintsUsed == 0 && controller.elapsed <= targetSeconds) {
      return 3;
    }
    if (controller.hintsUsed <= 2) {
      return 2;
    }
    return 1;
  }

  String _encouragementFor({
    required int stars,
    required bool isDaily,
    required bool isSpeed,
    required AppStrings strings,
  }) {
    if (isDaily) {
      return stars == 3 ? strings.dailyChampion : strings.dailyPuzzleComplete;
    }
    if (isSpeed) {
      return stars == 3 ? strings.lightningFast : strings.greatSpeedRun;
    }
    return switch (stars) {
      3 => strings.superFinder,
      2 => strings.greatFocus,
      _ => strings.nicePuzzleWork,
    };
  }

  WordCategory _nextCategory(WordCategory category) {
    final currentIndex = wordCategories.indexWhere(
      (item) => item.id == category.id,
    );
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % wordCategories.length;
    return wordCategories[nextIndex];
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final category = controller.category;
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final isSpeed = controller.isSpeed;
    final accentColor = isSpeed
        ? palette.speedButtonColor
        : palette.classicButtonColor;
    final perfect = controller.foundCount >= controller.totalCount;
    final stars = _starRating(controller);
    final learnedPlacements = controller.placements
        .where((placement) => placement.found)
        .take(6)
        .toList(growable: false);
    final encouragement = _encouragementFor(
      stars: stars,
      isDaily: widget.isDailyChallenge,
      isSpeed: isSpeed,
      strings: strings,
    );
    final nextCategory = _nextCategory(category);
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.height < 700;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 36),
              child: Transform.scale(scale: 0.96 + value * 0.04, child: child),
            ),
          );
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight:
                mediaQuery.size.height - mediaQuery.padding.vertical - 32,
          ),
          child: ClaySurface(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 22,
              compact ? 16 : 22,
              compact ? 16 : 22,
              compact ? 12 : 18,
            ),
            radius: 28,
            accentColor: accentColor,
            backgroundColor: palette.celebrationSurfaceStart,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RewardIcon(
                    icon: isSpeed && !perfect
                        ? Icons.timer
                        : Icons.emoji_events,
                    color: accentColor,
                  ),
                  const SizedBox(height: 6),
                  _DelayedReveal(
                    delay: const Duration(milliseconds: 70),
                    child: _StarRatingRow(stars: stars, color: accentColor),
                  ),
                  const SizedBox(height: 8),
                  _DelayedReveal(
                    delay: const Duration(milliseconds: 90),
                    child: Text(
                      isSpeed
                          ? (perfect ? strings.perfect : strings.timesUp)
                          : strings.puzzleSolved,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  _DelayedReveal(
                    delay: const Duration(milliseconds: 150),
                    child: Column(
                      children: [
                        Text(
                          encouragement,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.categoryProgressSummary(
                            categoryId: category.id,
                            found: controller.foundCount,
                            total: controller.totalCount,
                          ),
                          style: TextStyle(
                            color: palette.mutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DelayedReveal(
                    delay: Duration(
                      milliseconds: widget.isDailyChallenge ? 260 : 230,
                    ),
                    child: _RewardActionPanel(
                      color: accentColor,
                      isDailyChallenge: widget.isDailyChallenge,
                      isSpeed: isSpeed,
                      nextCategory: nextCategory,
                      onNextPuzzle: widget.onNextPuzzle == null
                          ? null
                          : () async {
                              try {
                                await widget.rewardFuture;
                                await widget.coinRewardFuture;
                              } catch (_) {
                                // Stats are best-effort; navigation should not get stuck.
                              }
                              await AdService.instance
                                  .showInterstitialIfAvailable();
                              if (context.mounted) {
                                widget.onNextPuzzle!(
                                  context,
                                  nextCategory,
                                  controller.difficulty,
                                  controller.mode,
                                );
                              }
                            },
                      onPlayAgain: () async {
                        await AdService.instance.showInterstitialIfAvailable();
                        await controller.restart();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _showRoundDetails = !_showRoundDetails);
                    },
                    icon: Icon(
                      _showRoundDetails
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    label: Text(
                      _showRoundDetails
                          ? strings.hideRoundDetails
                          : strings.roundDetails,
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatPill(
                                  label: isSpeed ? strings.found : strings.time,
                                  value: isSpeed
                                      ? '${controller.foundCount}/${controller.totalCount}'
                                      : formatSeconds(controller.elapsed),
                                  countTo: isSpeed
                                      ? controller.foundCount
                                      : controller.elapsed,
                                  formatter: isSpeed
                                      ? (value) =>
                                            '$value/${controller.totalCount}'
                                      : formatSeconds,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatPill(
                                  label: strings.score,
                                  value: '${controller.score}',
                                  countTo: controller.score,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatPill(
                                  label: isSpeed ? strings.time : strings.words,
                                  value: isSpeed
                                      ? formatSeconds(controller.elapsed)
                                      : '${controller.foundCount}/${controller.totalCount}',
                                  countTo: isSpeed
                                      ? controller.elapsed
                                      : controller.foundCount,
                                  formatter: isSpeed
                                      ? formatSeconds
                                      : (value) =>
                                            '$value/${controller.totalCount}',
                                ),
                              ),
                            ],
                          ),
                          if (widget.coinRewardFuture != null) ...[
                            const SizedBox(height: 10),
                            _CoinRewardCard(
                              color: accentColor,
                              rewardFuture: widget.coinRewardFuture!,
                            ),
                          ],
                          if (widget.isDailyChallenge) ...[
                            const SizedBox(height: 10),
                            _DailyCompleteCard(
                              color: accentColor,
                              streakFuture: widget.dailyStreakFuture,
                              onLeaderboard: widget.onLeaderboard,
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (learnedPlacements.isNotEmpty)
                            _RoundLearningCard(
                              color: accentColor,
                              category: category,
                              placements: learnedPlacements,
                            ),
                          if (learnedPlacements.isNotEmpty &&
                              widget.rewardFuture != null)
                            const SizedBox(height: 10),
                          if (widget.rewardFuture != null)
                            _RewardProgressCard(
                              color: accentColor,
                              rewardFuture: widget.rewardFuture!,
                            ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () {
                              setState(
                                () => _showScoreSubmission =
                                    !_showScoreSubmission,
                              );
                            },
                            icon: Icon(
                              _showScoreSubmission
                                  ? Icons.expand_less_rounded
                                  : Icons.emoji_events_outlined,
                            ),
                            label: Text(strings.scoreAndLeaderboard),
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _SubmitScoreBox(
                                state: _state,
                                errorMessage: _errorMessage,
                                rank: _rank,
                                aliasFuture: _aliasFuture,
                                color: accentColor,
                                onSubmit: _submit,
                                onLeaderboard: widget.onLeaderboard,
                              ),
                            ),
                            crossFadeState: _showScoreSubmission
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 220),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: _showRoundDetails
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),
                  _DelayedReveal(
                    delay: Duration(
                      milliseconds: widget.isDailyChallenge ? 640 : 570,
                    ),
                    child: TextButton.icon(
                      onPressed: () async {
                        await AdService.instance.showInterstitialIfAvailable();
                        widget.onBack();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: palette.bodyColor,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(strings.mainMenu),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRatingRow extends StatelessWidget {
  const _StarRatingRow({required this.stars, required this.color});

  final int stars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return CustomPaint(
      painter: _RewardSparkPainter(color: color, progress: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final active = index < stars;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: active ? 1 : 0.78),
            duration: Duration(milliseconds: 360 + index * 110),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.star_rounded,
                    color: active ? palette.hintColor : palette.tileBorder,
                    size: active ? 34 : 28,
                    shadows: active
                        ? [
                            Shadow(
                              color: palette.hintColor.withValues(alpha: 0.6),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _RewardActionPanel extends StatelessWidget {
  const _RewardActionPanel({
    required this.color,
    required this.isDailyChallenge,
    required this.isSpeed,
    required this.nextCategory,
    required this.onNextPuzzle,
    required this.onPlayAgain,
  });

  final Color color;
  final bool isDailyChallenge;
  final bool isSpeed;
  final WordCategory nextCategory;
  final VoidCallback? onNextPuzzle;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    if (isDailyChallenge) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: palette.sheetSurface.withValues(
                alpha: palette.isDark ? 0.68 : 0.58,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.event_available, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.comeBackTomorrow,
                    style: TextStyle(
                      color: palette.titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPlayAgain,
            style: OutlinedButton.styleFrom(
              backgroundColor: palette.sheetSurface.withValues(alpha: 0.62),
              foregroundColor: palette.bodyColor,
              side: BorderSide(color: palette.tileBorder),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.replay),
            label: Text(strings.playAgain),
          ),
        ],
      );
    }

    return Column(
      children: [
        FilledButton.icon(
          onPressed: onNextPuzzle,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: palette.headerButtonForeground,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.skip_next),
          label: Text(
            isSpeed ? strings.nextCategory(nextCategory.id) : strings.nextLevel,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onPlayAgain,
          style: OutlinedButton.styleFrom(
            backgroundColor: palette.sheetSurface.withValues(alpha: 0.62),
            foregroundColor: palette.bodyColor,
            side: BorderSide(color: palette.tileBorder),
            minimumSize: const Size.fromHeight(46),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.replay),
          label: Text(strings.playAgain),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.countTo,
    this.formatter,
  });

  final String label;
  final String value;
  final int? countTo;
  final String Function(int value)? formatter;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: palette.sheetSurface.withValues(
          alpha: palette.isDark ? 0.72 : 0.66,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.titleColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: countTo ?? 0),
            duration: const Duration(milliseconds: 760),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              final displayValue = countTo == null
                  ? value
                  : (formatter ?? (item) => '$item')(animatedValue);
              return Text(
                displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CoinRewardCard extends StatelessWidget {
  const _CoinRewardCard({required this.color, required this.rewardFuture});

  final Color color;
  final Future<CoinRewardResult> rewardFuture;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return FutureBuilder<CoinRewardResult>(
      future: rewardFuture,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final failed = snapshot.hasError;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.tileSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.tileBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFC928),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        failed
                            ? strings.rewardSaveFailed
                            : result == null
                            ? strings.coins
                            : result.earned > 0
                            ? strings.coinReward(result.earned)
                            : strings.levelRewardClaimed,
                        key: ValueKey((failed, result?.earned)),
                        style: TextStyle(
                          color: failed || result?.earned == 0
                              ? palette.mutedColor
                              : color,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (result != null)
                      Text(
                        strings.coinBalance(result.balance),
                        style: TextStyle(
                          color: palette.mutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RewardProgressCard extends StatelessWidget {
  const _RewardProgressCard({required this.color, required this.rewardFuture});

  final Color color;
  final Future<LocalRewardResult> rewardFuture;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return FutureBuilder<LocalRewardResult>(
      future: rewardFuture,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final failed = snapshot.hasError;
        final unlocked = result == null
            ? <RewardBadgeDefinition>[]
            : rewardBadges
                  .where(
                    (badge) => result.newlyUnlockedBadgeIds.contains(badge.id),
                  )
                  .toList(growable: false);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: palette.tileSurface.withValues(
              alpha: palette.isDark ? 0.8 : 0.86,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.rewards,
                      style: TextStyle(
                        color: palette.titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (failed)
                    Icon(
                      Icons.info_outline,
                      color: palette.mutedColor,
                      size: 17,
                    )
                  else if (result == null)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Text(
                      strings.starsEarned(result.starsEarned),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              if (failed) ...[
                const SizedBox(height: 7),
                Text(
                  strings.rewardSaveFailed,
                  style: TextStyle(
                    color: palette.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (result != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MiniRewardPill(
                      icon: Icons.star_rounded,
                      label: '${result.totalStars}',
                      color: palette.hintColor,
                    ),
                    if (unlocked.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${strings.newBadgeUnlocked}: ${unlocked.map((badge) => strings.badgeName(badge.id)).join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.bodyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RoundLearningCard extends StatefulWidget {
  const _RoundLearningCard({
    required this.color,
    required this.category,
    required this.placements,
  });

  final Color color;
  final WordCategory category;
  final List<WordPlacement> placements;

  @override
  State<_RoundLearningCard> createState() => _RoundLearningCardState();
}

class _RoundLearningCardState extends State<_RoundLearningCard> {
  final _store = const WordReviewStore();
  Set<String> _favoriteWords = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadFavorites());
  }

  Future<void> _loadFavorites() async {
    final records = await _store.getRecords();
    if (!mounted) {
      return;
    }
    final visibleWords = widget.placements
        .map((placement) => placement.word)
        .toSet();
    setState(() {
      _favoriteWords = records
          .where(
            (record) => record.isFavorite && visibleWords.contains(record.word),
          )
          .map((record) => record.word)
          .toSet();
    });
  }

  Future<void> _toggleFavorite(String word) async {
    final normalized = word.toUpperCase();
    final nextValue = !_favoriteWords.contains(normalized);
    setState(() {
      if (nextValue) {
        _favoriteWords = {..._favoriteWords, normalized};
      } else {
        _favoriteWords = _favoriteWords
            .where((favoriteWord) => favoriteWord != normalized)
            .toSet();
      }
    });
    await _store.setFavorite(
      word: normalized,
      isFavorite: nextValue,
      categoryId: widget.category.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.tileSurface.withValues(
          alpha: palette.isDark ? 0.8 : 0.88,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.11),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, color: widget.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.roundWordsLearned,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.tapWordAudio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: palette.mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final placement in widget.placements)
                _LearnedWordChip(
                  placement: placement,
                  categoryId: widget.category.id,
                  isFavorite: _favoriteWords.contains(placement.word),
                  onFavoriteToggle: () {
                    unawaited(_toggleFavorite(placement.word));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearnedWordChip extends StatelessWidget {
  const _LearnedWordChip({
    required this.placement,
    required this.categoryId,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final WordPlacement placement;
  final String categoryId;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final learning = wordLearningEntryFor(placement.word);
    final hasVisual =
        kidWordVisualAssetFor(placement.word, categoryId: categoryId) != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(VoiceGuideService.instance.playWord(placement.word));
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(5, 5, 7, 5),
          decoration: BoxDecoration(
            color: placement.color.withValues(
              alpha: isFavorite
                  ? (palette.isDark ? 0.28 : 0.2)
                  : (palette.isDark ? 0.2 : 0.14),
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: placement.color.withValues(alpha: isFavorite ? 0.48 : 0.3),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 178),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasVisual) ...[
                  WordIllustration(
                    word: placement.word,
                    categoryId: categoryId,
                    width: 40,
                    height: 40,
                    borderRadius: 9,
                  ),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        placement.word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.titleColor,
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        learning.meaningFor(strings.locale.languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.mutedColor,
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SpeakingWordIcon(
                  word: placement.word,
                  color: placement.color,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Tooltip(
                  message: isFavorite ? strings.savedWord : strings.saveWord,
                  child: InkResponse(
                    onTap: onFavoriteToggle,
                    radius: 17,
                    child: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_border,
                      color: isFavorite
                          ? const Color(0xFFFFB84D)
                          : palette.mutedColor.withValues(alpha: 0.72),
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniRewardPill extends StatelessWidget {
  const _MiniRewardPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: palette.tileSurface.withValues(
          alpha: palette.isDark ? 0.86 : 0.9,
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.tileBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCompleteCard extends StatelessWidget {
  const _DailyCompleteCard({
    required this.color,
    required this.streakFuture,
    required this.onLeaderboard,
  });

  final Color color;
  final Future<int>? streakFuture;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.tileSurface.withValues(
          alpha: palette.isDark ? 0.8 : 0.88,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.tileBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.today, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FutureBuilder<int>(
              future: streakFuture,
              builder: (context, snapshot) {
                final streak = snapshot.data;
                final nextDailyLabel = _nextDailyLabel(strings);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.dailyComplete,
                      style: TextStyle(
                        color: palette.titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      streak == null
                          ? strings.savingStreak
                          : strings.dailyStreakWithNext(streak, nextDailyLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.bodyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            onPressed: onLeaderboard,
            style: IconButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
            ),
            icon: const Icon(Icons.emoji_events, size: 20),
          ),
        ],
      ),
    );
  }

  String _nextDailyLabel(AppStrings strings) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final remaining = tomorrow.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours <= 0) {
      return strings.nextDailyLabel(hours: hours, minutes: minutes);
    }
    return strings.nextDailyLabel(hours: hours, minutes: minutes);
  }
}

class _DelayedReveal extends StatefulWidget {
  const _DelayedReveal({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.18),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _visible ? 1 : 0.96,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

class _RewardIcon extends StatelessWidget {
  const _RewardIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 760),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        final opacity = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.62 + value * 0.38,
            child: CustomPaint(
              painter: _RewardSparkPainter(color: color, progress: opacity),
              child: ClayIconBadge(
                icon: icon,
                color: color,
                size: 76,
                iconSize: 44,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RewardSparkPainter extends CustomPainter {
  const _RewardSparkPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: (1 - progress * 0.35) * 0.7);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + progress * math.pi * 0.45;
      final distance = 25 + progress * 18;
      final dot = center.translate(
        math.cos(angle) * distance,
        math.sin(angle) * distance,
      );
      canvas.drawCircle(dot, (2.8 - progress).clamp(1.0, 2.8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RewardSparkPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

class _SubmitScoreBox extends StatelessWidget {
  const _SubmitScoreBox({
    required this.state,
    required this.errorMessage,
    required this.rank,
    required this.aliasFuture,
    required this.color,
    required this.onSubmit,
    required this.onLeaderboard,
  });

  final String state;
  final String? errorMessage;
  final int? rank;
  final Future<String> aliasFuture;
  final Color color;
  final VoidCallback onSubmit;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.sheetSurface.withValues(
          alpha: palette.isDark ? 0.78 : 0.74,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: palette.titleColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: switch (state) {
        'submitting' => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                strings.savingScore,
                style: TextStyle(
                  color: palette.bodyColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        'done' => Column(
          children: [
            Icon(Icons.verified_rounded, color: color, size: 30),
            const SizedBox(height: 6),
            Text(
              strings.ranked(rank ?? 0),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onLeaderboard,
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.sheetSurface.withValues(alpha: 0.72),
                foregroundColor: palette.bodyColor,
                side: BorderSide(color: palette.tileBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.emoji_events),
              label: Text(strings.viewLeaderboard),
            ),
          ],
        ),
        _ => Column(
          children: [
            Text(
              strings.saveYourScore,
              style: TextStyle(
                color: palette.bodyColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: palette.tileSurface.withValues(
                        alpha: palette.isDark ? 0.84 : 0.9,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: state == 'error'
                            ? _winDialogError
                            : palette.tileBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.face_rounded,
                          color: color.withValues(alpha: 0.72),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: aliasFuture,
                            builder: (context, snapshot) => Text(
                              snapshot.data ?? strings.creatingNickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.titleColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onSubmit,
                  style: IconButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
            if (state == 'error')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage?.isNotEmpty == true
                      ? strings.localizedError(errorMessage)
                      : strings.failedSaveScore,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _winDialogError,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}
