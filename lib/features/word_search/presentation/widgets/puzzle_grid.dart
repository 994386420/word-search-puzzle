import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/puzzle_engine.dart';

class PuzzleGrid extends StatefulWidget {
  const PuzzleGrid({
    required this.puzzle,
    required this.placements,
    required this.hintCell,
    required this.hintCells,
    required this.hintTier,
    required this.recentlyFound,
    required this.accentColor,
    required this.onWordFound,
    required this.onWrongSelection,
    this.alignment = Alignment.center,
    super.key,
  });

  final PuzzleState puzzle;
  final List<WordPlacement> placements;
  final GridCell? hintCell;
  final List<GridCell> hintCells;
  final int hintTier;
  final WordPlacement? recentlyFound;
  final Color accentColor;
  final Future<void> Function(WordPlacement placement) onWordFound;
  final VoidCallback onWrongSelection;
  final Alignment alignment;

  @override
  State<PuzzleGrid> createState() => _PuzzleGridState();
}

class _PuzzleGridState extends State<PuzzleGrid> with TickerProviderStateMixin {
  late final AnimationController _hintPulseController;
  late final AnimationController _foundSweepController;
  GridCell? _start;
  GridCell? _current;
  List<GridCell> _failedCells = [];
  bool _wrongFlash = false;

  @override
  void initState() {
    super.initState();
    _hintPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _foundSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didUpdateWidget(covariant PuzzleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hintCells.isNotEmpty &&
        widget.hintCells != oldWidget.hintCells) {
      _hintPulseController.forward(from: 0);
    }
    if (widget.recentlyFound != null &&
        widget.recentlyFound?.word != oldWidget.recentlyFound?.word) {
      _foundSweepController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hintPulseController.dispose();
    _foundSweepController.dispose();
    super.dispose();
  }

  List<GridCell> get _selectedCells {
    final start = _start;
    final current = _current;
    if (start == null || current == null) {
      return const [];
    }
    return getSelectionCells(
      startRow: start.row,
      startCol: start.col,
      endRow: current.row,
      endCol: current.col,
      size: widget.puzzle.size,
    );
  }

  void _handleStart(Offset localPosition, double side) {
    final cell = _cellForOffset(localPosition, side);
    if (cell == null) {
      return;
    }
    setState(() {
      _start = cell;
      _current = cell;
      _wrongFlash = false;
    });
  }

  void _handleUpdate(Offset localPosition, double side) {
    final cell = _cellForOffset(localPosition, side);
    if (cell == null || cell == _current) {
      return;
    }
    setState(() => _current = cell);
  }

  Future<void> _handleEnd() async {
    final cells = _selectedCells;
    final match = checkWordMatch(cells, widget.puzzle.grid, widget.placements);
    if (match != null) {
      await widget.onWordFound(match);
    } else if (cells.length >= 2) {
      widget.onWrongSelection();
      setState(() {
        _failedCells = cells;
        _wrongFlash = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted) {
          setState(() {
            _wrongFlash = false;
            _failedCells = [];
          });
        }
      });
    }
    if (mounted) {
      setState(() {
        _start = null;
        _current = null;
      });
    }
  }

  GridCell? _cellForOffset(Offset offset, double side) {
    final size = widget.puzzle.size;
    if (offset.dx < 0 ||
        offset.dy < 0 ||
        offset.dx > side ||
        offset.dy > side) {
      return null;
    }
    final col = min(size - 1, (offset.dx / side * size).floor());
    final row = min(size - 1, (offset.dy / side * size).floor());
    return GridCell(row, col);
  }

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final activeCells = _wrongFlash && _failedCells.isNotEmpty
        ? _failedCells
        : _selectedCells;
    final activeSet = activeCells.toSet();
    final hintSet = widget.hintCells.toSet();
    final foundColors = <GridCell, Color>{};
    for (final placement in widget.placements) {
      if (placement.found) {
        for (final cell in getPlacementCells(placement)) {
          foundColors[cell] = placement.color;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return Align(
          alignment: widget.alignment,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _wrongFlash ? 1 : 0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, shake, child) {
              final offset = sin(shake * pi * 8) * (1 - shake) * 7;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Container(
              key: const ValueKey('puzzle-grid-board'),
              width: side,
              height: side,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(
                        alpha: palette.isDark ? 0.04 : 0.78,
                      ),
                      palette.boardSurface,
                    ),
                    palette.boardSurface.withValues(
                      alpha: palette.isDark ? 0.98 : 1,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Color.alphaBlend(
                    widget.accentColor.withValues(
                      alpha: palette.isDark ? 0.26 : 0.13,
                    ),
                    palette.tileBorder,
                  ),
                  width: 6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.titleColor.withValues(
                      alpha: palette.isDark ? 0.3 : 0.2,
                    ),
                    blurRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.09),
                    blurRadius: 24,
                    spreadRadius: -5,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: _PuzzleClayBoardPainter(
                  sizeCount: widget.puzzle.size,
                  palette: palette,
                  accentColor: widget.accentColor,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) =>
                      _handleStart(details.localPosition, side),
                  onPanUpdate: (details) =>
                      _handleUpdate(details.localPosition, side),
                  onPanEnd: (_) => _handleEnd(),
                  onPanCancel: _handleEnd,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _hintPulseController,
                      _foundSweepController,
                    ]),
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _GridHighlightPainter(
                          sizeCount: widget.puzzle.size,
                          placements: widget.placements,
                          selectedCells: activeCells,
                          recentlyFound: widget.recentlyFound,
                          foundSweep: _foundSweepController.value,
                          isWrongSelection: _wrongFlash,
                          accentColor: _wrongFlash
                              ? const Color(0xFFEF4444)
                              : widget.accentColor,
                          hintCell: widget.hintCell,
                          hintCells: widget.hintCells,
                          hintTier: widget.hintTier,
                          hintPulse: _hintPulseController.value,
                          hintColor: palette.hintColor,
                        ),
                        child: child,
                      );
                    },
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.puzzle.size,
                      ),
                      itemCount: widget.puzzle.size * widget.puzzle.size,
                      itemBuilder: (context, index) {
                        final row = index ~/ widget.puzzle.size;
                        final col = index % widget.puzzle.size;
                        final cell = GridCell(row, col);
                        final foundColor = foundColors[cell];
                        final isSelected = activeSet.contains(cell);
                        final isHint = hintSet.contains(cell);
                        final letterSize = widget.puzzle.size <= 10
                            ? 31.0
                            : widget.puzzle.size <= 13
                            ? 24.0
                            : 19.5;
                        return Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.puzzle.grid[row][col],
                              style: TextStyle(
                                color: isHint
                                    ? palette.hintColor
                                    : isSelected && _wrongFlash
                                    ? const Color(0xFFEF4444)
                                    : palette.boardLetterColor,
                                fontSize: letterSize,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(
                                      alpha: palette.isDark ? 0.08 : 0.85,
                                    ),
                                    blurRadius: 1,
                                    offset: const Offset(0, -1),
                                  ),
                                  Shadow(
                                    color: palette.titleColor.withValues(
                                      alpha: palette.isDark ? 0.38 : 0.2,
                                    ),
                                    blurRadius: 1.5,
                                    offset: const Offset(0, 2),
                                  ),
                                  if (foundColor != null)
                                    Shadow(
                                      color: foundColor.withValues(alpha: 0.22),
                                      blurRadius: 5,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PuzzleClayBoardPainter extends CustomPainter {
  const _PuzzleClayBoardPainter({
    required this.sizeCount,
    required this.palette,
    required this.accentColor,
  });

  final int sizeCount;
  final WordSearchPalette palette;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / sizeCount;
    final gap = (cell * 0.065).clamp(1.2, 2.8);
    final radius = Radius.circular((cell * 0.2).clamp(4.0, 9.0));
    final base = Color.alphaBlend(
      Colors.white.withValues(alpha: palette.isDark ? 0.035 : 0.62),
      palette.boardSurface,
    );
    final shadow = Paint()
      ..color = palette.titleColor.withValues(
        alpha: palette.isDark ? 0.3 : 0.2,
      );
    final fill = Paint()..color = base;
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: palette.isDark ? 0.055 : 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cell * 0.035).clamp(0.7, 1.4);
    final edge = Paint()
      ..color = Color.alphaBlend(
        accentColor.withValues(alpha: palette.isDark ? 0.13 : 0.055),
        palette.tileBorder,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cell * 0.03).clamp(0.7, 1.3);

    for (var row = 0; row < sizeCount; row++) {
      for (var col = 0; col < sizeCount; col++) {
        final tile = Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
        final shadowRect = tile.translate(0, (cell * 0.1).clamp(1.8, 4.0));
        canvas.drawRRect(RRect.fromRectAndRadius(shadowRect, radius), shadow);
        final rounded = RRect.fromRectAndRadius(tile, radius);
        canvas.drawRRect(rounded, fill);
        canvas.drawRRect(rounded, edge);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            tile.deflate((cell * 0.035).clamp(0.7, 1.4)),
            radius,
          ),
          highlight,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PuzzleClayBoardPainter oldDelegate) {
    return oldDelegate.sizeCount != sizeCount ||
        oldDelegate.palette != palette ||
        oldDelegate.accentColor != accentColor;
  }
}

class _GridHighlightPainter extends CustomPainter {
  const _GridHighlightPainter({
    required this.sizeCount,
    required this.placements,
    required this.selectedCells,
    required this.recentlyFound,
    required this.foundSweep,
    required this.isWrongSelection,
    required this.accentColor,
    required this.hintCell,
    required this.hintCells,
    required this.hintTier,
    required this.hintPulse,
    required this.hintColor,
  });

  final int sizeCount;
  final List<WordPlacement> placements;
  final List<GridCell> selectedCells;
  final WordPlacement? recentlyFound;
  final double foundSweep;
  final bool isWrongSelection;
  final Color accentColor;
  final GridCell? hintCell;
  final List<GridCell> hintCells;
  final int hintTier;
  final double hintPulse;
  final Color hintColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / sizeCount;
    for (final placement in placements.where((item) => item.found)) {
      final start = _center(placement.startRow, placement.startCol, cell);
      final end = _center(
        placement.startRow + placement.dr * (placement.word.length - 1),
        placement.startCol + placement.dc * (placement.word.length - 1),
        cell,
      );
      _drawRoundedPath(
        canvas,
        start,
        end,
        cell: cell,
        color: placement.color,
        alpha: 0.86,
        widthFactor: 0.76,
        glowAlpha: 0.13,
        shineAlpha: 0.18,
      );
    }

    _drawSelection(canvas, cell);

    final recent = recentlyFound;
    if (recent != null && foundSweep < 1) {
      final start = _center(recent.startRow, recent.startCol, cell);
      final end = _center(
        recent.startRow + recent.dr * (recent.word.length - 1),
        recent.startCol + recent.dc * (recent.word.length - 1),
        cell,
      );
      final eased = Curves.easeOutCubic.transform(foundSweep);
      final sweepEnd = Offset.lerp(start, end, eased)!;
      _drawRoundedPath(
        canvas,
        start,
        sweepEnd,
        cell: cell,
        color: recent.color,
        alpha: 0.9 * (1 - foundSweep * 0.1),
        widthFactor: 0.86,
        glowAlpha: (1 - foundSweep) * 0.4,
        shineAlpha: 0.5 * (1 - foundSweep * 0.15),
      );
      canvas.drawCircle(
        sweepEnd,
        cell * (0.24 + (1 - foundSweep) * 0.1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        sweepEnd,
        cell * (0.12 + (1 - foundSweep) * 0.08),
        Paint()
          ..color = recent.color.withValues(alpha: 0.88)
          ..style = PaintingStyle.fill,
      );
    }

    if (hintCells.isNotEmpty) {
      final blink = (sin(hintPulse * pi * 6) + 1) / 2;
      final fadeOut = hintPulse > 0.82 ? (1 - hintPulse) / 0.18 : 1.0;
      final opacity = (0.28 + blink * 0.72) * fadeOut.clamp(0.0, 1.0);
      final fillPaint = Paint()
        ..color = hintColor.withValues(alpha: 0.12 * opacity)
        ..style = PaintingStyle.fill;
      final ringPaint = Paint()
        ..color = hintColor.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      if (hintCells.length >= 2) {
        final pathPaint = Paint()
          ..color = hintColor.withValues(alpha: 0.28 * opacity)
          ..strokeWidth = cell * (hintTier >= 3 ? 0.56 : 0.42)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          _center(hintCells.first.row, hintCells.first.col, cell),
          _center(hintCells.last.row, hintCells.last.col, cell),
          pathPaint,
        );
      }
      for (final hint in hintCells) {
        final radius = cell * (0.32 + blink * 0.12);
        final center = _center(hint.row, hint.col, cell);
        canvas.drawCircle(center, cell * 0.4, fillPaint);
        canvas.drawCircle(center, radius, ringPaint);
      }
    }
  }

  Offset _center(int row, int col, double cell) {
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  void _drawSelection(Canvas canvas, double cell) {
    if (selectedCells.isEmpty) {
      return;
    }
    final start = _center(
      selectedCells.first.row,
      selectedCells.first.col,
      cell,
    );
    final end = _center(selectedCells.last.row, selectedCells.last.col, cell);
    final color = isWrongSelection ? const Color(0xFFEF4444) : accentColor;
    final alpha = isWrongSelection ? 0.88 : 0.74;
    if (selectedCells.length == 1) {
      canvas.drawCircle(
        start,
        cell * 0.46,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        start,
        cell * 0.34,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        start.translate(-cell * 0.08, -cell * 0.08),
        cell * 0.08,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill,
      );
      return;
    }

    _drawRoundedPath(
      canvas,
      start,
      end,
      cell: cell,
      color: color,
      alpha: alpha,
      widthFactor: isWrongSelection ? 0.72 : 0.8,
      glowAlpha: isWrongSelection ? 0.28 : 0.22,
      shineAlpha: isWrongSelection ? 0.12 : 0.32,
    );
    for (final point in [start, end]) {
      canvas.drawCircle(
        point,
        cell * 0.34,
        Paint()
          ..color = color.withValues(alpha: isWrongSelection ? 0.94 : 0.82)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        cell * 0.18,
        Paint()
          ..color = Colors.white.withValues(
            alpha: isWrongSelection ? 0.22 : 0.38,
          )
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawRoundedPath(
    Canvas canvas,
    Offset start,
    Offset end, {
    required double cell,
    required Color color,
    required double alpha,
    required double widthFactor,
    required double glowAlpha,
    required double shineAlpha,
  }) {
    if (glowAlpha > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: glowAlpha)
        ..strokeWidth = cell * (widthFactor + 0.22)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawLine(start, end, glowPaint);
    }
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = cell * widthFactor
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
    if (shineAlpha > 0) {
      final shinePaint = Paint()
        ..color = Colors.white.withValues(alpha: shineAlpha)
        ..strokeWidth = cell * 0.14
        ..strokeCap = StrokeCap.round;
      final normal = _pathNormal(start, end, cell * 0.15);
      canvas.drawLine(start + normal, end + normal, shinePaint);
    }
  }

  Offset _pathNormal(Offset start, Offset end, double distance) {
    final vector = end - start;
    final length = vector.distance;
    if (length == 0) {
      return Offset(-distance, -distance);
    }
    return Offset(
      -vector.dy / length * distance,
      vector.dx / length * distance,
    );
  }

  @override
  bool shouldRepaint(covariant _GridHighlightPainter oldDelegate) {
    return oldDelegate.placements != placements ||
        oldDelegate.selectedCells != selectedCells ||
        oldDelegate.recentlyFound != recentlyFound ||
        oldDelegate.foundSweep != foundSweep ||
        oldDelegate.isWrongSelection != isWrongSelection ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.hintCell != hintCell ||
        oldDelegate.hintCells != hintCells ||
        oldDelegate.hintTier != hintTier ||
        oldDelegate.hintPulse != hintPulse ||
        oldDelegate.hintColor != hintColor;
  }
}
