import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models.dart';

class SceneBackground extends StatefulWidget {
  const SceneBackground({
    required this.category,
    required this.difficulty,
    super.key,
  });

  final WordCategory category;
  final Difficulty difficulty;

  @override
  State<SceneBackground> createState() => _SceneBackgroundState();
}

class _SceneBackgroundState extends State<SceneBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          return CustomPaint(
            painter: _WordMapScenePainter(
              category: widget.category,
              difficulty: widget.difficulty,
              palette: palette,
              motion: _motion.value,
            ),
          );
        },
      ),
    );
  }
}

class _WordMapScenePainter extends CustomPainter {
  const _WordMapScenePainter({
    required this.category,
    required this.difficulty,
    required this.palette,
    required this.motion,
  });

  final WordCategory category;
  final Difficulty difficulty;
  final WordSearchPalette palette;
  final double motion;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = palette.pageGradient.createShader(rect),
    );
    _paintAmbientGlow(canvas, size);
    _paintOpenWordBook(canvas, size);
    _paintSearchRoutes(canvas, size);
    _paintFloatingLetters(canvas, size);
    _paintBottomTabs(canvas, size);
  }

  void _paintAmbientGlow(Canvas canvas, Size size) {
    final accent = category.accentColor;
    final difficultyColor = switch (difficulty) {
      Difficulty.easy => const Color(0xFF34D399),
      Difficulty.medium => const Color(0xFF38BDF8),
      Difficulty.hard => const Color(0xFFFF7A69),
    };
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    glowPaint.color = accent.withValues(alpha: palette.isDark ? 0.2 : 0.12);
    canvas.drawCircle(
      Offset(
        size.width * (0.18 + math.sin(motion * math.pi * 2) * 0.015),
        size.height * 0.2,
      ),
      size.width * 0.22,
      glowPaint,
    );

    glowPaint.color = difficultyColor.withValues(
      alpha: palette.isDark ? 0.16 : 0.1,
    );
    canvas.drawCircle(
      Offset(
        size.width * 0.82,
        size.height * (0.34 + math.cos(motion * math.pi * 2) * 0.012),
      ),
      size.width * 0.28,
      glowPaint,
    );
  }

  void _paintOpenWordBook(Canvas canvas, Size size) {
    final pageColor = palette.sheetSurface.withValues(
      alpha: palette.isDark ? 0.14 : 0.34,
    );
    final pageLineColor = palette.tileBorder.withValues(
      alpha: palette.isDark ? 0.1 : 0.22,
    );
    final spineColor = category.accentColor.withValues(
      alpha: palette.isDark ? 0.18 : 0.12,
    );

    final center = Offset(size.width * 0.5, size.height * 0.54);
    final pageWidth = size.width * 0.48;
    final pageHeight = size.height * 0.54;
    final leftPage = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(-pageWidth * 0.28, 0),
        width: pageWidth,
        height: pageHeight,
      ),
      const Radius.circular(24),
    );
    final rightPage = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(pageWidth * 0.28, 0),
        width: pageWidth,
        height: pageHeight,
      ),
      const Radius.circular(24),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.035);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(leftPage, Paint()..color = pageColor);
    _paintPageLines(canvas, leftPage.outerRect, pageLineColor);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.035);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(
      rightPage,
      Paint()
        ..color = palette.sheetSurface.withValues(
          alpha: palette.isDark ? 0.12 : 0.3,
        ),
    );
    _paintPageLines(canvas, rightPage.outerRect, pageLineColor);
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 18, height: pageHeight * 0.9),
        const Radius.circular(99),
      ),
      Paint()..color = spineColor,
    );
  }

  void _paintPageLines(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var y = rect.top + 34; y < rect.bottom - 24; y += 27) {
      canvas.drawLine(
        Offset(rect.left + 22, y),
        Offset(rect.right - 22, y),
        paint,
      );
    }
  }

  void _paintSearchRoutes(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.2
      ..color = category.accentColor.withValues(
        alpha: palette.isDark ? 0.2 : 0.17,
      );
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: palette.isDark ? 0.14 : 0.34);
    final phase = motion * math.pi * 2;
    final routes = [
      Path()
        ..moveTo(size.width * 0.12, size.height * 0.32)
        ..quadraticBezierTo(
          size.width * (0.42 + math.sin(phase) * 0.02),
          size.height * 0.18,
          size.width * 0.84,
          size.height * 0.3,
        ),
      Path()
        ..moveTo(size.width * 0.18, size.height * 0.76)
        ..quadraticBezierTo(
          size.width * 0.48,
          size.height * (0.65 + math.cos(phase) * 0.012),
          size.width * 0.78,
          size.height * 0.82,
        ),
      Path()
        ..moveTo(size.width * 0.77, size.height * 0.13)
        ..quadraticBezierTo(
          size.width * 0.63,
          size.height * 0.46,
          size.width * 0.9,
          size.height * 0.62,
        ),
    ];
    for (final path in routes) {
      canvas.drawPath(path, routePaint);
      canvas.drawPath(path, shinePaint);
    }
  }

  void _paintFloatingLetters(Canvas canvas, Size size) {
    final words = category.words;
    final letters = [
      for (var i = 0; i < math.min(words.length, 14); i++)
        words[(i * 3) % words.length].substring(0, 1),
    ];
    final positions = const [
      Offset(0.14, 0.17),
      Offset(0.3, 0.1),
      Offset(0.56, 0.12),
      Offset(0.82, 0.18),
      Offset(0.91, 0.36),
      Offset(0.1, 0.47),
      Offset(0.22, 0.63),
      Offset(0.84, 0.66),
      Offset(0.69, 0.9),
      Offset(0.38, 0.86),
      Offset(0.08, 0.86),
      Offset(0.92, 0.87),
      Offset(0.48, 0.27),
      Offset(0.61, 0.75),
    ];
    for (var i = 0; i < letters.length; i++) {
      final drift = math.sin(motion * math.pi * 2 + i) * 4;
      final center = Offset(
        size.width * positions[i].dx,
        size.height * positions[i].dy + drift,
      );
      final side = 23.0 + (i % 4) * 3;
      _paintLetterTile(
        canvas,
        center: center,
        side: side,
        letter: letters[i],
        angle: (i.isEven ? -1 : 1) * (0.09 + i * 0.006),
        color: i % 5 == 0 ? palette.hintColor : category.accentColor,
        filled: i % 3 == 0,
      );
    }
  }

  void _paintLetterTile(
    Canvas canvas, {
    required Offset center,
    required double side,
    required String letter,
    required double angle,
    required Color color,
    required bool filled,
  }) {
    final rect = Rect.fromCenter(center: center, width: side, height: side);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(side * 0.28));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = filled
            ? color.withValues(alpha: palette.isDark ? 0.18 : 0.24)
            : Colors.white.withValues(alpha: palette.isDark ? 0.08 : 0.3),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: palette.isDark ? 0.2 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: color.withValues(alpha: palette.isDark ? 0.44 : 0.38),
          fontSize: side * 0.5,
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

  void _paintBottomTabs(Canvas canvas, Size size) {
    final baseY = size.height * 0.93;
    final colors = [
      category.accentColor,
      palette.classicButtonColor,
      palette.speedButtonColor,
      palette.hintColor,
    ];
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.08 + i * 0.2);
      final height = 44.0 + (i % 2) * 12;
      final rect = Rect.fromLTWH(x, baseY - height, size.width * 0.13, height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = colors[i % colors.length].withValues(
            alpha: palette.isDark ? 0.12 : 0.08,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WordMapScenePainter oldDelegate) {
    return oldDelegate.category.id != category.id ||
        oldDelegate.difficulty != difficulty ||
        oldDelegate.palette != palette ||
        oldDelegate.motion != motion;
  }
}
