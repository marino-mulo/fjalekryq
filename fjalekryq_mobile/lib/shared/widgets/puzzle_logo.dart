import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// The app's brand mark: a purple rounded tile containing a small
/// crossword-style 3×3 grid with letters in some cells.
///
/// Set [animated] = true on splash / loading screens — letters light up
/// in sequence (a "solve sweep") which reads as crossword-themed motion.
class PuzzleLogo extends StatefulWidget {
  final double size;
  final bool animated;

  const PuzzleLogo({
    super.key,
    this.size = 88,
    this.animated = false,
  });

  @override
  State<PuzzleLogo> createState() => _PuzzleLogoState();
}

/// One cell in the mini crossword. Either a letter cell ([letter] != null)
/// or a "blocker" cell (filled black-square — the empty squares of a
/// crossword grid).
class _Cell {
  final String? letter;
  final int row;
  final int col;
  const _Cell(this.row, this.col, [this.letter]);
}

// 3×3 mini-crossword:
//
//   [F][J][A]
//   [ ][L][ ]
//   [ ][Ë][ ]
//
// Top row spells "FJA" (start of "FJALË" — Albanian for "word"); the
// centre column reads "JLË" — a real-looking crossword intersection.
const _cells = <_Cell>[
  _Cell(0, 0, 'F'),
  _Cell(0, 1, 'J'),
  _Cell(0, 2, 'A'),
  _Cell(1, 0),
  _Cell(1, 1, 'L'),
  _Cell(1, 2),
  _Cell(2, 0),
  _Cell(2, 1, 'Ë'),
  _Cell(2, 2),
];

class _PuzzleLogoState extends State<PuzzleLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animated) _startAnim();
  }

  @override
  void didUpdateWidget(covariant PuzzleLogo old) {
    super.didUpdateWidget(old);
    if (widget.animated && _ctrl == null) {
      _startAnim();
    } else if (!widget.animated && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  void _startAnim() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null) return _buildTile(progress: -1);

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (_, __) => _buildTile(progress: _ctrl!.value),
    );
  }

  Widget _buildTile({required double progress}) {
    final radius = widget.size * 0.22;
    final border = (widget.size * 0.023).clamp(1.5, 3.0);
    final blur = widget.size * 0.36;
    final spread = widget.size * 0.023;
    final innerPad = widget.size * 0.12;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.purpleAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.purpleAccent.withValues(alpha: 0.45),
          width: border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleAccent.withValues(alpha: 0.3),
            blurRadius: blur,
            spreadRadius: spread,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(innerPad),
        child: _buildGrid(progress: progress),
      ),
    );
  }

  Widget _buildGrid({required double progress}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final cellSize = side / 3;
        final gap = cellSize * 0.06;

        final letterCells = _cells.where((c) => c.letter != null).toList();
        final litIndex = progress < 0
            ? -1
            : (progress * letterCells.length).floor() % letterCells.length;
        final litCell = litIndex < 0 ? null : letterCells[litIndex];

        final stepSize = 1.0 / letterCells.length;
        final localT = progress < 0
            ? 0.0
            : ((progress - litIndex * stepSize) / stepSize).clamp(0.0, 1.0);
        final pulse = localT < 0.5 ? localT * 2 : (1 - localT) * 2;

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              for (final c in _cells)
                Positioned(
                  left: c.col * cellSize + gap,
                  top: c.row * cellSize + gap,
                  width: cellSize - gap * 2,
                  height: cellSize - gap * 2,
                  child: _buildCell(
                    c,
                    side: cellSize - gap * 2,
                    highlight: litCell == c ? pulse : 0.0,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCell(_Cell c, {required double side, required double highlight}) {
    if (c.letter == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1240).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(side * 0.18),
        ),
      );
    }

    final base = AppColors.purpleAccent.withValues(alpha: 0.32);
    final hot = AppColors.gold.withValues(alpha: 0.85);
    final fill = Color.lerp(base, hot, highlight)!;
    final letterColor = Color.lerp(
      const Color(0xFFEDE7FF),
      const Color(0xFFFFF6D6),
      highlight,
    )!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(side * 0.18),
        border: Border.all(
          color: Color.lerp(
            AppColors.purpleAccent.withValues(alpha: 0.6),
            AppColors.gold,
            highlight,
          )!,
          width: 1.2,
        ),
        boxShadow: highlight > 0
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.45 * highlight),
                  blurRadius: side * 0.35 * highlight,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        c.letter!,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: side * 0.62,
          color: letterColor,
          height: 1.0,
        ),
      ),
    );
  }
}
