import 'dart:math' as math;

import 'package:flutter/material.dart';

class GameRefreshIndicator extends StatefulWidget {
  const GameRefreshIndicator({
    required this.child,
    required this.onRefresh,
    required this.color,
    this.icon = Icons.auto_awesome,
    super.key,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final Color color;
  final IconData icon;

  @override
  State<GameRefreshIndicator> createState() => _GameRefreshIndicatorState();
}

class _GameRefreshIndicatorState extends State<GameRefreshIndicator> {
  RefreshIndicatorStatus? _status;
  final ValueNotifier<double> _pullDistance = ValueNotifier<double>(0);

  bool get _isSettled =>
      _status == RefreshIndicatorStatus.snap ||
      _status == RefreshIndicatorStatus.refresh;

  double _contentOffsetFor(double distance) {
    if (_isSettled) {
      return 46;
    }
    return (distance * 0.55).clamp(0.0, 58.0);
  }

  double _pullProgressFor(double distance) => (distance / 84).clamp(0.0, 1.0);

  void _setPullDistance(double value) {
    _pullDistance.value = value.clamp(0.0, 110.0);
  }

  void _setStatus(RefreshIndicatorStatus? status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      if (status == RefreshIndicatorStatus.snap ||
          status == RefreshIndicatorStatus.refresh) {
        _setPullDistance(84);
      }
    });
    if (status == RefreshIndicatorStatus.canceled ||
        status == RefreshIndicatorStatus.done) {
      _setPullDistance(0);
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted && _status == status) {
          setState(() => _status = null);
        }
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isSettled) {
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.metrics.extentBefore == 0 &&
        notification.overscroll < 0) {
      _setPullDistance(_pullDistance.value - notification.overscroll);
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.extentBefore == 0) {
      final delta = notification.scrollDelta ?? 0;
      if (delta < 0) {
        _setPullDistance(_pullDistance.value - delta);
      } else if (_pullDistance.value > 0) {
        _setPullDistance(_pullDistance.value - delta * 1.4);
      }
    } else if (notification is ScrollEndNotification &&
        _status != RefreshIndicatorStatus.refresh &&
        _status != RefreshIndicatorStatus.snap) {
      _setPullDistance(0);
    }

    return false;
  }

  @override
  void dispose() {
    _pullDistance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pullDistance,
      builder: (context, child) {
        final distance = _pullDistance.value;
        final contentOffset = _contentOffsetFor(distance);
        final pullProgress = _pullProgressFor(distance);
        final visible = _status != null || distance > 14;

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: RefreshIndicator.noSpinner(
                onRefresh: widget.onRefresh,
                onStatusChange: _setStatus,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: contentOffset),
                  duration: _isSettled || contentOffset == 0
                      ? const Duration(milliseconds: 220)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, value),
                      child: child,
                    );
                  },
                  child: widget.child,
                ),
              ),
            ),
            Positioned(
              top: 6 + (contentOffset * 0.24),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(0, -0.55),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: Center(
                      child: _RefreshBadge(
                        status: _status,
                        color: widget.color,
                        icon: widget.icon,
                        pullProgress: pullProgress,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RefreshBadge extends StatefulWidget {
  const _RefreshBadge({
    required this.status,
    required this.color,
    required this.icon,
    required this.pullProgress,
  });

  final RefreshIndicatorStatus? status;
  final Color color;
  final IconData icon;
  final double pullProgress;

  @override
  State<_RefreshBadge> createState() => _RefreshBadgeState();
}

class _RefreshBadgeState extends State<_RefreshBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _refreshing =>
      widget.status == RefreshIndicatorStatus.refresh ||
      widget.status == RefreshIndicatorStatus.snap;

  bool get _armed => widget.status == RefreshIndicatorStatus.armed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _RefreshBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  void _syncController() {
    if (_refreshing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_refreshing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readiness = _refreshing ? 1.0 : widget.pullProgress;
    final letters = widget.icon == Icons.emoji_events
        ? const ['R', 'A', 'N', 'K']
        : const ['W', 'O', 'R', 'D'];
    return AnimatedScale(
      scale: 0.9 + readiness * 0.1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 154,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(
            0xFF15152F,
          ).withValues(alpha: 0.18 + readiness * 0.12),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(
                alpha: _refreshing ? 0.24 : readiness * 0.12,
              ),
              blurRadius: 14 + readiness * 14,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final spin = _refreshing ? _controller.value : 0.0;
            final pulse = _refreshing
                ? (math.sin(_controller.value * math.pi * 2) + 1) / 2
                : (_armed ? 1.0 : readiness);
            return CustomPaint(
              painter: _WordScanPainter(
                color: widget.color,
                progress: _refreshing ? spin : readiness,
                pulse: pulse,
                refreshing: _refreshing,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < letters.length; i++) ...[
                    _LetterTile(
                      letter: letters[i],
                      color: widget.color,
                      index: i,
                      progress: readiness,
                      scan: spin,
                      refreshing: _refreshing,
                    ),
                    if (i != letters.length - 1) const SizedBox(width: 5),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.color,
    required this.index,
    required this.progress,
    required this.scan,
    required this.refreshing,
  });

  final String letter;
  final Color color;
  final int index;
  final double progress;
  final double scan;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final threshold = (index + 1) / 4;
    final armedAmount = ((progress - threshold + 0.28) / 0.28).clamp(0.0, 1.0);
    final scanCenter = refreshing ? scan * 4 : -1.0;
    final scanHit = refreshing
        ? (1 - (scanCenter - index).abs()).clamp(0.0, 1.0)
        : 0.0;
    final lift = refreshing ? scanHit : armedAmount;
    final glow = math.max(armedAmount, scanHit);
    return Transform.translate(
      offset: Offset(0, (1 - armedAmount) * 7 - scanHit * 3),
      child: Transform.scale(
        scale: 0.86 + armedAmount * 0.1 + scanHit * 0.08,
        child: Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: Color.lerp(
              Colors.white.withValues(alpha: 0.06),
              color.withValues(alpha: 0.26),
              glow,
            ),
            border: Border.all(
              color: Color.lerp(
                Colors.white.withValues(alpha: 0.08),
                color.withValues(alpha: 0.48),
                glow,
              )!,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2 * glow),
                blurRadius: 12 + lift * 8,
              ),
            ],
          ),
          child: Text(
            letter,
            style: TextStyle(
              color: Color.lerp(Colors.white54, Colors.white, glow),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _WordScanPainter extends CustomPainter {
  const _WordScanPainter({
    required this.color,
    required this.progress,
    required this.pulse,
    required this.refreshing,
  });

  final Color color;
  final double progress;
  final double pulse;
  final bool refreshing;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    if (refreshing) {
      final x = 18 + (size.width - 36) * progress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.55 + pulse * 0.25),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x - 20, 0, 40, size.height));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 18, 4, 36, size.height - 8),
          const Radius.circular(14),
        ),
        scanPaint,
      );

      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.35 + pulse * 0.25);
      for (var i = 0; i < 4; i++) {
        final angle = progress * math.pi * 2 + i * math.pi / 2;
        canvas.drawCircle(
          Offset(
            size.width / 2 + math.cos(angle) * (52 + pulse * 3),
            centerY + math.sin(angle) * (10 + pulse * 2),
          ),
          1.4 + pulse * 0.5,
          dotPaint,
        );
      }
    } else if (progress > 0.72) {
      final sparkPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: (progress - 0.72) / 0.28 * 0.45);
      for (var i = 0; i < 5; i++) {
        final angle = i * math.pi * 0.4;
        canvas.drawCircle(
          Offset(
            size.width / 2 + math.cos(angle) * 63,
            centerY + math.sin(angle) * 14,
          ),
          1.2,
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WordScanPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.refreshing != refreshing;
  }
}
