import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/ad_service.dart';
import '../../data/feedback_service.dart';
import '../../data/level_progress_store.dart';
import '../../data/product_analytics_service.dart';
import '../../data/theme_access_store.dart';
import '../../data/word_review_store.dart';
import '../../domain/categories.dart';
import '../../domain/level_progression.dart';
import '../../domain/models.dart';
import '../widgets/category_thumbnail.dart';
import '../widgets/clay_ui.dart';
import '../widgets/theme_scene_assets.dart';
import '../widgets/word_illustration.dart';
import 'theme_level_screen.dart';
import 'word_review_screen.dart';

class KidsHubScreen extends StatefulWidget {
  const KidsHubScreen({
    required this.onStartLevel,
    required this.onStart,
    super.key,
  });

  final Future<void> Function(LevelDefinition level) onStartLevel;

  final void Function(
    WordCategory category,
    Difficulty difficulty,
    ClueMode clueMode,
    GameMode gameMode,
  )
  onStart;

  @override
  State<KidsHubScreen> createState() => _KidsHubScreenState();
}

class _KidsHubScreenState extends State<KidsHubScreen> {
  final _levelProgressStore = const LevelProgressStore();
  final _accessStore = const ThemeAccessStore();
  final _reviewStore = const WordReviewStore();
  LevelProgressSnapshot? _levelProgress;
  Set<String> _dailyUnlocks = const {};
  bool _familyAccess = false;
  bool _unlocking = false;
  int _dueReviewCount = 0;
  ClueMode _clueMode = ClueMode.pictures;
  Difficulty _difficulty = Difficulty.easy;
  GameMode _gameMode = GameMode.classic;
  bool _customPlay = false;

  @override
  void initState() {
    super.initState();
    unawaited(ProductAnalyticsService.instance.record('kids_hub_open'));
    unawaited(AdService.instance.loadRewarded());
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object>([
      _accessStore.dailyUnlockedThemeIds(),
      _accessStore.hasFamilyAccess(),
      _reviewStore.getDueRecords(),
      _levelProgressStore.load(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _dailyUnlocks = values[0] as Set<String>;
      _familyAccess = values[1] as bool;
      _dueReviewCount = (values[2] as List<LearnedWordRecord>).length;
      _levelProgress = values[3] as LevelProgressSnapshot;
    });
  }

  bool _isThemeUnlocked(int index) {
    if (_familyAccess || index < 2) {
      return true;
    }
    final category = wordCategories[index];
    if (_dailyUnlocks.contains(category.id)) {
      return true;
    }
    final previous = wordCategories[index - 1];
    return (_levelProgress?.completedInTheme(previous.id) ?? 0) >=
        levelsRequiredToUnlockNextTheme;
  }

  Future<void> _openTheme(WordCategory category, int index) async {
    if (_isThemeUnlocked(index)) {
      if (_customPlay) {
        _start(category);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThemeLevelScreen(
              category: category,
              onStartLevel: widget.onStartLevel,
            ),
          ),
        );
        await _load();
      }
      return;
    }
    unawaited(
      ProductAnalyticsService.instance.record(
        'theme_unlock_prompt',
        properties: {'theme': category.id},
      ),
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      showDragHandle: false,
      builder: (context) => _UnlockSheet(
        category: category,
        canWatchVideo: AdService.instance.isSupported,
      ),
    );
    if (action != 'watch' || !mounted) {
      return;
    }
    setState(() => _unlocking = true);
    final earned = await AdService.instance.showRewardedUnlock();
    if (earned) {
      await _accessStore.unlockForToday(category.id);
      await ProductAnalyticsService.instance.record(
        'theme_rewarded_unlock',
        properties: {'theme': category.id},
      );
      await _load();
    }
    if (!mounted) {
      return;
    }
    setState(() => _unlocking = false);
    if (earned) {
      await _openTheme(category, index);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).rewardedUnavailable)),
      );
    }
  }

  void _start(WordCategory category) {
    unawaited(
      ProductAnalyticsService.instance.record(
        'kids_puzzle_start',
        properties: {
          'theme': category.id,
          'difficulty': _difficulty.storageName,
          'clue': _clueMode.storageName,
          'mode': _gameMode.storageName,
        },
      ),
    );
    widget.onStart(category, _difficulty, _clueMode, _gameMode);
  }

  Future<void> _showCustomPlaySettings() async {
    unawaited(FeedbackService.instance.tap());
    final selection = await showModalBottomSheet<_CustomPlaySelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      showDragHandle: false,
      builder: (_) => _CustomPlaySettingsSheet(
        clueMode: _clueMode,
        difficulty: _difficulty,
        gameMode: _gameMode,
      ),
    );
    if (!mounted || selection == null) {
      return;
    }
    final clueChanged = selection.clueMode != _clueMode;
    setState(() {
      _clueMode = selection.clueMode;
      _difficulty = selection.difficulty;
      _gameMode = selection.gameMode;
    });
    if (clueChanged) {
      unawaited(
        ProductAnalyticsService.instance.record(
          'clue_mode_select',
          properties: {'clue': selection.clueMode.storageName},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final activeLevel = _levelProgress?.activeLevel ?? firstCampaignLevel();
    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: ClayPageHeader(
                  title: _customPlay
                      ? strings.playAndLearn
                      : strings.wordsThemesTitle,
                  subtitle: strings.seeHearFind,
                  height: 72,
                  titleFontSize: 26,
                  onBack: () => Navigator.of(context).pop(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_unlocking) ...[
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(width: 7),
                      ],
                      _HubIconButton(
                        key: const ValueKey('review-button'),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WordReviewScreen(),
                            ),
                          );
                          await _load();
                        },
                        tooltip: strings.reviewWords,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Center(
                              child: Icon(
                                Icons.school_rounded,
                                key: ValueKey('review-button-icon'),
                              ),
                            ),
                            if (_dueReviewCount > 0)
                              Positioned(
                                top: -2,
                                right: -3,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: palette.headerButtonBackground,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    _dueReviewCount > 99
                                        ? '99+'
                                        : '$_dueReviewCount',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                      fontSize: 10,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: _PlayTypeSwitcher(
                  customPlay: _customPlay,
                  onChanged: (customPlay) {
                    setState(() => _customPlay = customPlay);
                  },
                ),
              ),
              if (_customPlay)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  child: _CustomPlaySummary(
                    clueMode: _clueMode,
                    difficulty: _difficulty,
                    gameMode: _gameMode,
                    onTap: _showCustomPlaySettings,
                  ),
                ),
              if (_customPlay) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 7),
                  child: Row(
                    children: [
                      Text(
                        strings.chooseCategory,
                        style: TextStyle(
                          color: palette.pageForegroundColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        strings.levelPackProgress(
                          _levelProgress?.results.length ?? 0,
                          campaignLevels.length,
                        ),
                        style: TextStyle(
                          color: palette.pageMutedForegroundColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: wordCategories.length,
                    itemBuilder: (context, index) {
                      final category = wordCategories[index];
                      final completions =
                          _levelProgress?.completedInTheme(category.id) ?? 0;
                      final unlocked = _isThemeUnlocked(index);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ThemeTile(
                          category: category,
                          unlocked: unlocked,
                          completions: completions,
                          stars: _levelProgress?.starsInTheme(category.id) ?? 0,
                          recommended:
                              unlocked &&
                              category.id == activeLevel.category.id,
                          lockLabel: index < 2
                              ? null
                              : strings.completeThemeLevelsToUnlock(
                                  strings.categoryName(
                                    wordCategories[index - 1].id,
                                  ),
                                  levelsRequiredToUnlockNextTheme,
                                ),
                          onTap: _unlocking
                              ? null
                              : () => _openTheme(category, index),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                Expanded(
                  child: _ThemeWorldMap(
                    progress: _levelProgress,
                    activeLevel: activeLevel,
                    isUnlocked: _isThemeUnlocked,
                    onOpen: _unlocking ? null : _openTheme,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: _customPlay
          ? ClaySceneBackdrop(
              assetPath: 'assets/ui/clay/scenes/picture-garden-v1.webp',
              foregroundGradient: palette.isDark,
              child: content,
            )
          : ClaySceneBackdrop(
              assetPath: 'assets/ui/clay/scenes/game-garden-v1.webp',
              foregroundGradient: palette.isDark,
              child: content,
            ),
    );
  }
}

class _ThemeWorldMap extends StatelessWidget {
  const _ThemeWorldMap({
    required this.progress,
    required this.activeLevel,
    required this.isUnlocked,
    required this.onOpen,
  });

  final LevelProgressSnapshot? progress;
  final LevelDefinition activeLevel;
  final bool Function(int index) isUnlocked;
  final Future<void> Function(WordCategory category, int index)? onOpen;

  static const _positions = <Alignment>[
    Alignment(-0.42, -0.82),
    Alignment(0.42, -0.5),
    Alignment(-0.4, -0.18),
    Alignment(0.4, 0.14),
    Alignment(-0.38, 0.47),
    Alignment(0.38, 0.79),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: const _ThemeTrailPainter(positions: _positions),
          ),
        ),
        for (var index = 0; index < wordCategories.length; index++)
          Align(
            alignment: _positions[index],
            child: _ThemeMapNode(
              index: index,
              category: wordCategories[index],
              unlocked: isUnlocked(index),
              completed:
                  progress?.completedInTheme(wordCategories[index].id) ?? 0,
              stars: progress?.starsInTheme(wordCategories[index].id) ?? 0,
              current: wordCategories[index].id == activeLevel.category.id,
              onTap: onOpen == null
                  ? null
                  : () => onOpen!(wordCategories[index], index),
            ),
          ),
      ],
    );
  }
}

class _ThemeMapNode extends StatelessWidget {
  const _ThemeMapNode({
    required this.index,
    required this.category,
    required this.unlocked,
    required this.completed,
    required this.stars,
    required this.current,
    required this.onTap,
  });

  final int index;
  final WordCategory category;
  final bool unlocked;
  final int completed;
  final int stars;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: strings.categoryName(category.id),
      value: strings.completedLevelCount(completed, levelsPerTheme),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 166,
            height: 112,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: index.isEven
                      ? Alignment.topLeft
                      : Alignment.topRight,
                  child: AnimatedScale(
                    scale: current ? 1.08 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: ColorFiltered(
                      colorFilter: unlocked
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            )
                          : const ColorFilter.matrix(<double>[
                              0.25,
                              0.25,
                              0.25,
                              0,
                              80,
                              0.25,
                              0.25,
                              0.25,
                              0,
                              80,
                              0.25,
                              0.25,
                              0.25,
                              0,
                              80,
                              0,
                              0,
                              0,
                              0.72,
                              0,
                            ]),
                      child: Container(
                        width: 92,
                        height: 92,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ClayWorldColors.creamHighlight,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: current
                                ? ClayWorldColors.yellow
                                : unlocked
                                ? category.accentColor
                                : ClayWorldColors.creamEdge,
                            width: current ? 4 : 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ClayWorldColors.deepPurpleShadow
                                  .withValues(alpha: current ? 0.36 : 0.24),
                              blurRadius: current ? 16 : 4,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: WordIllustration(
                          word: clayThemeLandmarkWord(category),
                          categoryId: category.id,
                          width: 84,
                          height: 84,
                          borderRadius: 25,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  left: index.isEven ? 78 : null,
                  right: index.isOdd ? 78 : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? ClayWorldColors.deepPurple
                          : palette.sheetSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current
                            ? ClayWorldColors.yellow
                            : ClayWorldColors.cream,
                        width: current ? 3.5 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ClayWorldColors.deepPurpleShadow.withValues(
                            alpha: 0.38,
                          ),
                          blurRadius: 5,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: unlocked
                        ? const Icon(
                            Icons.star_rounded,
                            color: ClayWorldColors.yellow,
                            size: 25,
                          )
                        : Icon(
                            Icons.lock_rounded,
                            color: palette.mutedColor,
                            size: 19,
                          ),
                  ),
                ),
                Positioned(
                  left: index.isEven ? 0 : 54,
                  bottom: 0,
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                    decoration: BoxDecoration(
                      color: palette.sheetSurface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: unlocked
                            ? category.accentColor.withValues(alpha: 0.55)
                            : palette.tileBorder,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40351545),
                          blurRadius: 1,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            strings.categoryName(category.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.titleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          color: ClayWorldColors.yellow,
                          size: 13,
                        ),
                        Text(
                          '$stars',
                          style: TextStyle(
                            color: palette.mutedColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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

class _ThemeTrailPainter extends CustomPainter {
  const _ThemeTrailPainter({required this.positions});

  final List<Alignment> positions;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) {
      return;
    }
    final centers = positions
        .map(
          (alignment) => Offset(
            (alignment.x + 1) * size.width / 2,
            (alignment.y + 1) * size.height / 2,
          ),
        )
        .toList(growable: false);
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var index = 1; index < centers.length; index++) {
      final from = centers[index - 1];
      final to = centers[index];
      final middleY = (from.dy + to.dy) / 2;
      path.cubicTo(from.dx, middleY, to.dx, middleY, to.dx, to.dy);
    }
    canvas.save();
    canvas.translate(0, 7);
    canvas.drawPath(
      path,
      Paint()
        ..color = ClayWorldColors.deepPurpleShadow.withValues(alpha: 0.32)
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = ClayWorldColors.cream
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ClayWorldColors.deepPurple.withValues(alpha: 0.76)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ThemeTrailPainter oldDelegate) => false;
}

class _HubIconButton extends StatelessWidget {
  const _HubIconButton({
    required this.onPressed,
    required this.tooltip,
    required this.child,
    super.key,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return ClayPressable(
      onTap: onPressed,
      semanticLabel: tooltip,
      color: palette.headerButtonBackground,
      shadowColor: palette.headerButtonBorder,
      radius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox.square(dimension: 42, child: child),
    );
  }
}

class _PlayTypeSwitcher extends StatelessWidget {
  const _PlayTypeSwitcher({required this.customPlay, required this.onChanged});

  final bool customPlay;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: _PlayTypeOption(
              selected: !customPlay,
              icon: Icons.route_rounded,
              label: strings.adventureLevels,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PlayTypeOption(
              selected: customPlay,
              icon: Icons.tune_rounded,
              label: strings.customPlay,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayTypeOption extends StatelessWidget {
  const _PlayTypeOption({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final foreground = selected ? Colors.white : palette.titleColor;
    return ClayPressable(
      onTap: onTap,
      color: selected ? ClayWorldColors.teal : palette.sheetSurface,
      shadowColor: selected ? ClayWorldColors.tealShadow : palette.tileBorder,
      radius: 18,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 46,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 19),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomPlaySummary extends StatelessWidget {
  const _CustomPlaySummary({
    required this.clueMode,
    required this.difficulty,
    required this.gameMode,
    required this.onTap,
  });

  final ClueMode clueMode;
  final Difficulty difficulty;
  final GameMode gameMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return ClayPressable(
      onTap: onTap,
      color: palette.tileSurface,
      shadowColor: palette.tileBorder,
      radius: 20,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.iconSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: palette.titleColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.playSettings,
                      style: TextStyle(
                        color: palette.titleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${strings.clueModeLabel(clueMode)} · ${strings.difficultyLabel(difficulty)} · ${strings.modeLabel(gameMode)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.mutedColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomPlaySelection {
  const _CustomPlaySelection({
    required this.clueMode,
    required this.difficulty,
    required this.gameMode,
  });

  final ClueMode clueMode;
  final Difficulty difficulty;
  final GameMode gameMode;
}

class _CustomPlaySettingsSheet extends StatefulWidget {
  const _CustomPlaySettingsSheet({
    required this.clueMode,
    required this.difficulty,
    required this.gameMode,
  });

  final ClueMode clueMode;
  final Difficulty difficulty;
  final GameMode gameMode;

  @override
  State<_CustomPlaySettingsSheet> createState() =>
      _CustomPlaySettingsSheetState();
}

class _CustomPlaySettingsSheetState extends State<_CustomPlaySettingsSheet> {
  late ClueMode _clueMode = widget.clueMode;
  late Difficulty _difficulty = widget.difficulty;
  late GameMode _gameMode = widget.gameMode;

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
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            radius: 28,
            accentColor: ClayWorldColors.teal,
            backgroundColor: palette.sheetSurface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.tileBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.titleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: palette.titleColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      strings.playSettings,
                      style: TextStyle(
                        color: palette.titleColor,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: strings.chooseClueMode,
                  child: _ClueModeControl(
                    value: _clueMode,
                    onChanged: (value) => setState(() => _clueMode = value),
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsSection(
                  title: strings.chooseDifficulty,
                  child: _DifficultyControl(
                    value: _difficulty,
                    onChanged: (value) => setState(() => _difficulty = value),
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsSection(
                  title: strings.chooseGameMode,
                  child: _GameModeControl(
                    value: _gameMode,
                    onChanged: (value) => setState(() => _gameMode = value),
                  ),
                ),
                const SizedBox(height: 18),
                ClayPressable(
                  onTap: () {
                    unawaited(FeedbackService.instance.tap());
                    Navigator.of(context).pop(
                      _CustomPlaySelection(
                        clueMode: _clueMode,
                        difficulty: _difficulty,
                        gameMode: _gameMode,
                      ),
                    );
                  },
                  color: ClayWorldColors.coral,
                  shadowColor: ClayWorldColors.coralShadow,
                  radius: 18,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, color: Colors.white),
                        const SizedBox(width: 7),
                        Text(
                          strings.done,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.bodyColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _ClueModeControl extends StatelessWidget {
  const _ClueModeControl({required this.value, required this.onChanged});

  final ClueMode value;
  final ValueChanged<ClueMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      children: [
        for (final mode in ClueMode.values) ...[
          Expanded(
            child: _KidChoiceButton(
              selected: value == mode,
              icon: switch (mode) {
                ClueMode.words => Icons.text_fields_rounded,
                ClueMode.pictures => Icons.image_rounded,
                ClueMode.sounds => Icons.volume_up_rounded,
                ClueMode.memory => Icons.visibility_off_rounded,
              },
              label: strings.clueModeLabel(mode),
              onTap: () => onChanged(mode),
              height: 54,
            ),
          ),
          if (mode != ClueMode.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _DifficultyControl extends StatelessWidget {
  const _DifficultyControl({required this.value, required this.onChanged});

  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      children: [
        for (final difficulty in Difficulty.values) ...[
          Expanded(
            child: _KidChoiceButton(
              selected: value == difficulty,
              icon: switch (difficulty) {
                Difficulty.easy => Icons.looks_one_rounded,
                Difficulty.medium => Icons.looks_two_rounded,
                Difficulty.hard => Icons.looks_3_rounded,
              },
              label: strings.difficultyLabel(difficulty),
              onTap: () => onChanged(difficulty),
              height: 46,
              horizontal: true,
            ),
          ),
          if (difficulty != Difficulty.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _GameModeControl extends StatelessWidget {
  const _GameModeControl({required this.value, required this.onChanged});

  final GameMode value;
  final ValueChanged<GameMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      children: [
        for (final mode in GameMode.values) ...[
          Expanded(
            child: _KidChoiceButton(
              selected: value == mode,
              icon: mode == GameMode.classic
                  ? Icons.sentiment_satisfied_alt_rounded
                  : Icons.timer_rounded,
              label: strings.modeLabel(mode),
              onTap: () => onChanged(mode),
              height: 46,
              horizontal: true,
            ),
          ),
          if (mode != GameMode.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _KidChoiceButton extends StatelessWidget {
  const _KidChoiceButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.height,
    this.horizontal = false,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double height;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final foreground = selected ? Colors.white : palette.bodyColor;
    final contents = [
      Icon(icon, color: foreground, size: horizontal ? 18 : 20),
      SizedBox(width: horizontal ? 6 : 0, height: horizontal ? 0 : 3),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ];
    return ClayPressable(
      onTap: onTap,
      color: selected ? ClayWorldColors.teal : palette.tileSurface,
      shadowColor: selected ? ClayWorldColors.tealShadow : palette.tileBorder,
      radius: 15,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SizedBox(
        height: height,
        child: horizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: contents,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: contents,
              ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.category,
    required this.unlocked,
    required this.completions,
    required this.stars,
    required this.recommended,
    required this.lockLabel,
    required this.onTap,
  });

  final WordCategory category;
  final bool unlocked;
  final int completions;
  final int stars;
  final bool recommended;
  final String? lockLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final accent = category.accentColor;
    final progress = (completions / levelsPerTheme).clamp(0.0, 1.0);
    final surface = Color.alphaBlend(
      accent.withValues(alpha: unlocked ? 0.12 : 0.035),
      palette.sheetSurface,
    );
    return ClayPressable(
      onTap: onTap,
      color: surface,
      shadowColor: unlocked
          ? Color.alphaBlend(accent.withValues(alpha: 0.42), palette.titleColor)
          : palette.tileBorder,
      radius: 32,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 116,
        child: Row(
          children: [
            Container(
              width: 108,
              height: 108,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.sheetSurface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: unlocked ? 0.34 : 0.12),
                    blurRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: ColorFiltered(
                  colorFilter: unlocked
                      ? const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.dst,
                        )
                      : const ColorFilter.mode(
                          Color(0xFF83918C),
                          BlendMode.saturation,
                        ),
                  child: Image.asset(category.assetPath, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.categoryName(category.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.titleColor,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: 0.72),
                                offset: const Offset(0, -1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (unlocked)
                        Icon(
                          recommended
                              ? Icons.play_circle_fill_rounded
                              : Icons.chevron_right_rounded,
                          color: recommended ? accent : palette.titleColor,
                          size: recommended ? 30 : 25,
                        )
                      else
                        Icon(Icons.lock_rounded, color: accent, size: 24),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (unlocked) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: ClayWorldColors.yellow,
                          size: 19,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$stars',
                          style: TextStyle(
                            color: palette.bodyColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${completions.clamp(0, levelsPerTheme)} / $levelsPerTheme',
                          style: TextStyle(
                            color: palette.bodyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) => Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette.iconSurface,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: palette.titleColor.withValues(alpha: 0.14),
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          width: constraints.maxWidth * progress,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Text(
                      lockLabel ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mutedColor,
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockSheet extends StatelessWidget {
  const _UnlockSheet({required this.category, required this.canWatchVideo});

  final WordCategory category;
  final bool canWatchVideo;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ClayBottomSheetShell(
      accentColor: category.accentColor,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryThumbnail(category: category, size: 72, borderRadius: 20),
          const SizedBox(height: 8),
          Text(
            strings.unlockTheme(strings.categoryName(category.id)),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            canWatchVideo
                ? strings.unlockThemeBody
                : strings.unlockThemeWithoutVideo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (canWatchVideo) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop('watch'),
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: Text(strings.watchToUnlock),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.keepPlayingToUnlock),
          ),
        ],
      ),
    );
  }
}
