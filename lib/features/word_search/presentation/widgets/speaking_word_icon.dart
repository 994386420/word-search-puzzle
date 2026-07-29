import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/voice_guide_service.dart';

class SpeakingWordIcon extends StatelessWidget {
  const SpeakingWordIcon({
    required this.word,
    required this.color,
    this.size = 14,
    super.key,
  });

  final String word;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: VoiceGuideService.instance.activeWordListenable,
      builder: (context, activeWord, _) {
        return _SpeakingIconVisual(
          active: activeWord == word.toUpperCase(),
          color: color,
          size: size,
        );
      },
    );
  }
}

class _SpeakingIconVisual extends StatefulWidget {
  const _SpeakingIconVisual({
    required this.active,
    required this.color,
    required this.size,
  });

  final bool active;
  final Color color;
  final double size;

  @override
  State<_SpeakingIconVisual> createState() => _SpeakingIconVisualState();
}

class _SpeakingIconVisualState extends State<_SpeakingIconVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SpeakingIconVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
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
      return Icon(
        Icons.volume_up_rounded,
        color: widget.color,
        size: widget.size,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final wave = math.sin(_controller.value * math.pi * 2);
        final scale = 1 + wave.abs() * 0.16;
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            painter: _SpeakingWavePainter(
              color: widget.color,
              progress: _controller.value,
            ),
            child: SizedBox.square(
              dimension: widget.size + 8,
              child: Center(
                child: Icon(
                  Icons.volume_up_rounded,
                  color: widget.color,
                  size: widget.size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpeakingWavePainter extends CustomPainter {
  const _SpeakingWavePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final phase = ((progress + i * 0.42) % 1.0);
      paint.color = color.withValues(alpha: (1 - phase) * 0.42);
      canvas.drawCircle(center, size.width * (0.28 + phase * 0.32), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeakingWavePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
