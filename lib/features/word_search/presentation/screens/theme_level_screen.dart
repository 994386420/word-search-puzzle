import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/feedback_service.dart';
import '../../data/level_progress_store.dart';
import '../../domain/level_progression.dart';
import '../../domain/models.dart';
import '../widgets/clay_ui.dart';
import '../widgets/theme_scene_assets.dart';
import '../widgets/word_illustration.dart';

class ThemeLevelScreen extends StatefulWidget {
  const ThemeLevelScreen({
    required this.category,
    required this.onStartLevel,
    super.key,
  });

  final WordCategory category;
  final Future<void> Function(LevelDefinition level) onStartLevel;

  @override
  State<ThemeLevelScreen> createState() => _ThemeLevelScreenState();
}

class _ThemeLevelScreenState extends State<ThemeLevelScreen> {
  final _progressStore = const LevelProgressStore();
  LevelProgressSnapshot? _progress;
  bool _openingLevel = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final progress = await _progressStore.load();
    if (mounted) {
      setState(() => _progress = progress);
    }
  }

  Future<void> _openLevel(LevelDefinition level) async {
    if (_openingLevel) {
      return;
    }
    setState(() => _openingLevel = true);
    unawaited(FeedbackService.instance.tap());
    await widget.onStartLevel(level);
    await _load();
    if (mounted) {
      setState(() => _openingLevel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final progress = _progress;
    final completed = progress?.completedInTheme(widget.category.id) ?? 0;
    final stars = progress?.starsInTheme(widget.category.id) ?? 0;
    final current =
        progress?.nextLevelInTheme(widget.category) ??
        levelForTheme(widget.category, 1);
    return Scaffold(
      body: ClaySceneBackdrop(
        assetPath: clayThemeSceneAsset(widget.category),
        foregroundGradient: palette.isDark,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClayPageHeader(
                      title: strings.categoryName(widget.category.id),
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                  _ThemeLevelHero(
                    category: widget.category,
                    completed: completed,
                    stars: stars,
                  ),
                  ClaySurface(
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    radius: 18,
                    accentColor: widget.category.accentColor,
                    elevated: false,
                    child: Row(
                      children: [
                        Text(
                          strings.levelMap,
                          style: TextStyle(
                            color: palette.pageForegroundColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _openingLevel
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: widget.category.accentColor,
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      strings.nextThemeLevel(
                                        current.themeLevel,
                                      ),
                                      style: TextStyle(
                                        color: widget.category.accentColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      strings.puzzleRuleSummary(
                                        current.puzzleConfig,
                                        current.clueMode,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.pageMutedForegroundColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
                      child: _LevelPath(
                        category: widget.category,
                        progress: progress,
                        current: current,
                        onOpen: _openingLevel ? null : _openLevel,
                      ),
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

class _ThemeLevelHero extends StatelessWidget {
  const _ThemeLevelHero({
    required this.category,
    required this.completed,
    required this.stars,
  });

  final WordCategory category;
  final int completed;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return SizedBox(
      width: double.infinity,
      height: 166,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: ClayWorldColors.creamHighlight,
              borderRadius: BorderRadius.circular(38),
              border: Border.all(color: category.accentColor, width: 4),
              boxShadow: [
                BoxShadow(
                  color: ClayWorldColors.deepPurpleShadow.withValues(
                    alpha: 0.28,
                  ),
                  blurRadius: 4,
                  offset: const Offset(0, 9),
                ),
                BoxShadow(
                  color: category.accentColor.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: WordIllustration(
              word: clayThemeLandmarkWord(category),
              categoryId: category.id,
              width: 122,
              height: 122,
              borderRadius: 32,
            ),
          ),
          Positioned(
            left: 26,
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.sheetSurface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: category.accentColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40351545),
                    blurRadius: 1,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                strings.themeLevelSummary(completed, levelsPerTheme),
                style: TextStyle(
                  color: palette.titleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ClayWorldColors.deepPurple,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClayWorldColors.cream, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: ClayWorldColors.deepPurpleShadow,
                    blurRadius: 1,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: ClayWorldColors.yellow,
                    size: 19,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$stars/${levelsPerTheme * 3}',
                    style: const TextStyle(
                      color: ClayWorldColors.creamHighlight,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPath extends StatelessWidget {
  const _LevelPath({
    required this.category,
    required this.progress,
    required this.current,
    required this.onOpen,
  });

  final WordCategory category;
  final LevelProgressSnapshot? progress;
  final LevelDefinition current;
  final ValueChanged<LevelDefinition>? onOpen;

  @override
  Widget build(BuildContext context) {
    final levels = campaignLevels
        .where((level) => level.category.id == category.id)
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const rowHeight = 92.0;
        final rows = levels.length;
        final centers = <Offset>[];
        for (var index = 0; index < levels.length; index++) {
          final factor = switch (index % 4) {
            0 => 0.34,
            1 => 0.62,
            2 => 0.72,
            _ => 0.45,
          };
          centers.add(
            Offset(width * factor, index * rowHeight + rowHeight / 2),
          );
        }
        return SizedBox(
          width: width,
          height: rows * rowHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LevelPathPainter(
                    centers: centers,
                    color: category.accentColor,
                  ),
                ),
              ),
              for (var index = 0; index < levels.length; index++)
                Positioned(
                  left: centers[index].dx - 38,
                  top: centers[index].dy - 40,
                  child: _LevelNode(
                    level: levels[index],
                    result: progress?.resultFor(levels[index]),
                    current: levels[index].id == current.id,
                    locked:
                        index > 0 &&
                        !(progress?.isCompleted(levels[index - 1]) ?? false),
                    color: category.accentColor,
                    onTap: onOpen == null ? null : () => onOpen!(levels[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.result,
    required this.current,
    required this.locked,
    required this.color,
    required this.onTap,
  });

  final LevelDefinition level;
  final LevelResult? result;
  final bool current;
  final bool locked;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final completed = result?.completed ?? false;
    final interactive = onTap != null;
    final fill = locked ? palette.sheetSurface : ClayWorldColors.deepPurple;
    final foreground = locked ? palette.mutedColor : ClayWorldColors.deepPurple;

    void handleTap() {
      if (!locked) {
        onTap?.call();
        return;
      }
      unawaited(FeedbackService.instance.wrongSelection());
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: math.min(340.0, MediaQuery.sizeOf(context).width - 24),
          duration: const Duration(milliseconds: 1800),
          backgroundColor: palette.sheetSurface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.tileBorder),
          ),
          content: Row(
            children: [
              Icon(Icons.lock_rounded, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.completeLevelToUnlock(level.themeLevel - 1),
                  style: TextStyle(
                    color: palette.bodyColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 76,
      height: 80,
      child: Column(
        children: [
          _CurrentNodePulse(
            active: current,
            child: Material(
              color: fill,
              shape: CircleBorder(
                side: BorderSide(
                  color: current
                      ? ClayWorldColors.yellow
                      : completed
                      ? ClayWorldColors.teal
                      : locked
                      ? palette.tileBorder
                      : ClayWorldColors.cream,
                  width: current ? 4 : 2,
                ),
              ),
              elevation: current ? 10 : 5,
              shadowColor: ClayWorldColors.deepPurpleShadow.withValues(
                alpha: 0.5,
              ),
              child: InkWell(
                onTap: interactive ? handleTap : null,
                customBorder: const CircleBorder(),
                child: SizedBox.square(
                  dimension: 58,
                  child: Center(
                    child: locked
                        ? Icon(Icons.lock_rounded, color: foreground, size: 21)
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: ClayWorldColors.yellow,
                                size: 40,
                              ),
                              Text(
                                '${level.themeLevel}',
                                style: const TextStyle(
                                  color: ClayWorldColors.deepPurple,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 15,
            child: completed
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final active = index < (result?.stars ?? 0);
                      return Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: active
                            ? const Color(0xFFFFB21C)
                            : palette.tileBorder,
                      );
                    }),
                  )
                : current
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: color, size: 15),
                      Icon(_clueIcon(level.clueMode), color: color, size: 13),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  IconData _clueIcon(ClueMode mode) => switch (mode) {
    ClueMode.words => Icons.text_fields_rounded,
    ClueMode.pictures => Icons.image_rounded,
    ClueMode.sounds => Icons.headphones_rounded,
    ClueMode.memory => Icons.visibility_off_rounded,
  };
}

class _CurrentNodePulse extends StatefulWidget {
  const _CurrentNodePulse({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_CurrentNodePulse> createState() => _CurrentNodePulseState();
}

class _CurrentNodePulseState extends State<_CurrentNodePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _CurrentNodePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(scale: 1 + value * 0.07, child: child);
      },
    );
  }
}

class _LevelPathPainter extends CustomPainter {
  const _LevelPathPainter({required this.centers, required this.color});

  final List<Offset> centers;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) {
      return;
    }
    final shadowPaint = Paint()
      ..color = ClayWorldColors.deepPurpleShadow.withValues(alpha: 0.22)
      ..strokeWidth = 27
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final creamPaint = Paint()
      ..color = ClayWorldColors.cream
      ..strokeWidth = 23
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final paint = Paint()
      ..color = ClayWorldColors.deepPurple.withValues(alpha: 0.76)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var index = 1; index < centers.length; index++) {
      final from = centers[index - 1];
      final to = centers[index];
      final controlY = (from.dy + to.dy) / 2;
      path.cubicTo(from.dx, controlY, to.dx, controlY, to.dx, to.dy);
    }
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
    canvas.drawPath(path, creamPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = color.withValues(alpha: 0.18);
    for (var index = 0; index < centers.length - 1; index++) {
      final from = centers[index];
      final to = centers[index + 1];
      for (var step = 1; step < 4; step++) {
        final point = Offset.lerp(from, to, step / 4)!;
        canvas.drawCircle(point, 2 + math.sin(step * math.pi / 4), dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LevelPathPainter oldDelegate) {
    return oldDelegate.centers != centers || oldDelegate.color != color;
  }
}
