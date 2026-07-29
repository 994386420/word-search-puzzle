import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../domain/models.dart';
import '../../domain/puzzle_engine.dart';
import 'category_thumbnail.dart';

class CategoryCard extends StatefulWidget {
  const CategoryCard({
    required this.category,
    required this.difficulty,
    required this.mode,
    required this.doneCount,
    required this.onTap,
    super.key,
  });

  final WordCategory category;
  final Difficulty difficulty;
  final GameMode mode;
  final int doneCount;
  final VoidCallback onTap;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final wordCount = widget.difficulty.wordCount;
    final isSpeed = widget.mode == GameMode.speed;
    final complete = !isSpeed && widget.doneCount >= wordCount && wordCount > 0;
    final foundCount = widget.doneCount.clamp(0, wordCount);
    final pct = wordCount == 0 ? 0.0 : (foundCount / wordCount).clamp(0.0, 1.0);
    final progressLabel = isSpeed
        ? strings.speedRun
        : complete
        ? strings.completedPuzzle
        : strings.currentPuzzleProgress(found: foundCount, total: wordCount);
    final previewWords = getWordsForDifficulty(
      widget.category.words,
      widget.difficulty,
    ).take(3).toList(growable: false);
    final accent = widget.category.accentColor;
    final surface = Color.lerp(
      palette.sheetSurface,
      accent,
      palette.isDark ? 0.08 : 0.045,
    )!;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerCancel: (_) => setState(() => _pressed = false),
      onPointerUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.982 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: 118,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color.lerp(
                    palette.tileBorder,
                    accent,
                    palette.isDark ? 0.36 : 0.2,
                  )!,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: palette.isDark ? 0.26 : 0.1,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                  BoxShadow(
                    color: accent.withValues(
                      alpha: palette.isDark ? 0.18 : 0.12,
                    ),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _WordKitCardPainter(
                      category: widget.category,
                      palette: palette,
                      progress: isSpeed ? 1 : pct,
                      complete: complete,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
                    child: Row(
                      children: [
                        _CategoryStamp(
                          category: widget.category,
                          complete: complete,
                          isSpeed: isSpeed,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      strings.categoryName(widget.category.id),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.titleColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _MiniModeMark(
                                    color: isSpeed
                                        ? palette.speedButtonColor
                                        : palette.classicButtonColor,
                                    icon: isSpeed
                                        ? Icons.timer_rounded
                                        : Icons.search_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _PreviewWordStrip(
                                words: previewWords,
                                color: accent,
                                palette: palette,
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PencilProgressLine(
                                      value: isSpeed ? 1 : pct,
                                      color: complete
                                          ? const Color(0xFF22C55E)
                                          : accent,
                                      palette: palette,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  _ProgressBadge(
                                    label: progressLabel,
                                    color: complete
                                        ? const Color(0xFF22C55E)
                                        : accent,
                                    complete: complete,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _CategoryStamp extends StatelessWidget {
  const _CategoryStamp({
    required this.category,
    required this.complete,
    required this.isSpeed,
  });

  final WordCategory category;
  final bool complete;
  final bool isSpeed;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final color = category.accentColor;
    return SizedBox(
      width: 70,
      height: 90,
      child: Stack(
        children: [
          Positioned(
            left: 5,
            right: 5,
            top: 3,
            bottom: 7,
            child: Transform.rotate(
              angle: -0.045,
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    palette.tileSurface,
                    color,
                    palette.isDark ? 0.18 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: color.withValues(
                      alpha: palette.isDark ? 0.44 : 0.28,
                    ),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.16),
                      blurRadius: 13,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: CategoryThumbnail(
                    category: category,
                    size: 48,
                    borderRadius: 14,
                    showBorder: false,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _LetterTile(
              letter: category.words.first.substring(0, 1),
              color: color,
              size: 24,
              angle: -0.18,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _LetterTile(
              letter: complete
                  ? null
                  : isSpeed
                  ? '!'
                  : category.words[1].substring(0, 1),
              icon: complete ? Icons.check_rounded : null,
              color: complete ? const Color(0xFF22C55E) : color,
              size: 26,
              angle: 0.13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.color,
    required this.size,
    required this.angle,
    this.icon,
  });

  final String? letter;
  final IconData? icon;
  final Color color;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.34)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: icon != null
            ? Icon(icon, color: color, size: size * 0.58)
            : Text(
                letter ?? '',
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

class _MiniModeMark extends StatelessWidget {
  const _MiniModeMark({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

class _PreviewWordStrip extends StatelessWidget {
  const _PreviewWordStrip({
    required this.words,
    required this.color,
    required this.palette,
  });

  final List<String> words;
  final Color color;
  final WordSearchPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final visibleWords = constraints.maxWidth < 185
              ? words.take(2).toList(growable: false)
              : words;
          return Row(
            children: [
              for (var i = 0; i < visibleWords.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Flexible(
                  child: _WordChip(
                    word: visibleWords[i],
                    color: color,
                    palette: palette,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.color,
    required this.palette,
  });

  final String word;
  final Color color;
  final WordSearchPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        word,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.bodyColor.withValues(alpha: 0.88),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PencilProgressLine extends StatelessWidget {
  const _PencilProgressLine({
    required this.value,
    required this.color,
    required this.palette,
  });

  final double value;
  final Color color;
  final WordSearchPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: CustomPaint(
        painter: _PencilProgressPainter(
          value: value,
          color: color,
          backgroundColor: palette.tileBorder.withValues(
            alpha: palette.isDark ? 0.4 : 0.72,
          ),
          paperColor: palette.sheetSurface,
        ),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.label,
    required this.color,
    required this.complete,
  });

  final String label;
  final Color color;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 126),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (complete) ...[
            Icon(Icons.check_circle, color: color, size: 13),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.bodyColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordKitCardPainter extends CustomPainter {
  const _WordKitCardPainter({
    required this.category,
    required this.palette,
    required this.progress,
    required this.complete,
  });

  final WordCategory category;
  final WordSearchPalette palette;
  final double progress;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = category.accentColor;
    _paintPaperGrain(canvas, size, accent);
    _paintBookmark(canvas, size, accent);
    _paintSearchTrail(canvas, size, accent);
    _paintLetterField(canvas, size, accent);

    if (complete) {
      final sealPaint = Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final center = Offset(size.width - 44, 33);
      canvas.drawCircle(center, 22, sealPaint);
      canvas.drawLine(
        center.translate(-9, 1),
        center.translate(-2, 8),
        sealPaint,
      );
      canvas.drawLine(
        center.translate(-2, 8),
        center.translate(11, -8),
        sealPaint,
      );
    }
  }

  void _paintPaperGrain(Canvas canvas, Size size, Color accent) {
    final line = Paint()
      ..color = palette.tileBorder.withValues(alpha: palette.isDark ? 0.1 : 0.2)
      ..strokeWidth = 1;
    for (var y = 18.0; y < size.height; y += 18) {
      canvas.drawLine(Offset(96, y), Offset(size.width - 18, y - 1), line);
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: palette.isDark ? 0.22 : 0.14),
              accent.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.14, size.height * 0.38),
              radius: 102,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  void _paintBookmark(Canvas canvas, Size size, Color accent) {
    final path = Path()
      ..moveTo(size.width - 47, 0)
      ..lineTo(size.width - 15, 0)
      ..lineTo(size.width - 15, 60)
      ..lineTo(size.width - 31, 48)
      ..lineTo(size.width - 47, 60)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = accent.withValues(alpha: palette.isDark ? 0.32 : 0.18),
    );
  }

  void _paintSearchTrail(Canvas canvas, Size size, Color accent) {
    final trail = Paint()
      ..color = accent.withValues(alpha: palette.isDark ? 0.24 : 0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.36, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.54,
        size.height * (0.47 - progress * 0.06),
        size.width * (0.74 + progress * 0.08),
        size.height * 0.62,
      );
    canvas.drawPath(path, trail);
    final endpoint = Offset(
      size.width * (0.74 + progress * 0.08),
      size.height * 0.62,
    );
    canvas.drawCircle(
      endpoint,
      4.5,
      Paint()..color = accent.withValues(alpha: 0.32),
    );
  }

  void _paintLetterField(Canvas canvas, Size size, Color accent) {
    final words = category.words;
    final letters = [
      for (var i = 0; i < math.min(words.length, 8); i++)
        words[i].substring(0, 1),
    ];
    final positions = const [
      Offset(0.8, 0.23),
      Offset(0.91, 0.47),
      Offset(0.67, 0.23),
      Offset(0.56, 0.84),
      Offset(0.38, 0.18),
      Offset(0.86, 0.82),
      Offset(0.72, 0.82),
      Offset(0.48, 0.57),
    ];
    for (var i = 0; i < letters.length; i++) {
      final center = Offset(
        size.width * positions[i].dx,
        size.height * positions[i].dy,
      );
      final tileSize = 18.0 + (i % 3) * 2;
      final rect = Rect.fromCenter(
        center: center,
        width: tileSize,
        height: tileSize,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      final opacity = palette.isDark ? 0.08 : 0.2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((i.isEven ? -1 : 1) * (0.08 + i * 0.01));
      canvas.translate(-center.dx, -center.dy);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = accent.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: TextStyle(
            color: accent.withValues(alpha: palette.isDark ? 0.32 : 0.24),
            fontSize: tileSize * 0.54,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WordKitCardPainter oldDelegate) {
    return oldDelegate.category.id != category.id ||
        oldDelegate.palette != palette ||
        oldDelegate.progress != progress ||
        oldDelegate.complete != complete;
  }
}

class _PencilProgressPainter extends CustomPainter {
  const _PencilProgressPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.paperColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * 0.56;
    final basePaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(2, baseline),
      Offset(size.width - 8, baseline),
      basePaint,
    );

    final progressWidth = (size.width - 10) * value.clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..shader = LinearGradient(colors: [color.withValues(alpha: 0.78), color])
          .createShader(
            Rect.fromLTWH(0, 0, math.max(progressWidth, 1), size.height),
          )
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(2, baseline),
      Offset(2 + progressWidth, baseline),
      progressPaint,
    );

    final tipX = (2 + progressWidth).clamp(8.0, size.width - 5);
    final tip = Path()
      ..moveTo(tipX + 5, baseline)
      ..lineTo(tipX - 2, baseline - 5)
      ..lineTo(tipX - 2, baseline + 5)
      ..close();
    canvas.drawPath(tip, Paint()..color = color.withValues(alpha: 0.92));
    canvas.drawCircle(
      Offset(tipX - 4, baseline),
      2.3,
      Paint()..color = paperColor.withValues(alpha: 0.86),
    );
  }

  @override
  bool shouldRepaint(covariant _PencilProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.paperColor != paperColor;
  }
}
