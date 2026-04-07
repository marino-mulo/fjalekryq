import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/game_service.dart';
import '../../../shared/constants/theme.dart';

/// Cell size lookup to keep total board fitting the screen width.
const _cellSizeMap = {5: 64.0, 6: 56.0, 7: 50.0, 8: 44.0, 9: 38.0, 10: 34.0, 11: 31.0, 12: 28.0, 13: 26.0};
const _fontSizeMap = {5: 28.0, 6: 24.0, 7: 21.0, 8: 18.0, 9: 16.0, 10: 14.0, 11: 12.0, 12: 11.0, 13: 10.0};

/// The game board rendered as a grid of animated, tappable cells.
class GameBoard extends StatefulWidget {
  final GameService game;
  final List<({int row, int col})> tutorialHighlight;
  final bool disableSwap;

  const GameBoard({
    super.key,
    required this.game,
    this.tutorialHighlight = const [],
    this.disableSwap = false,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  late AnimationController _winController;
  late Animation<double> _winBounce;
  bool _winAnimPlayed = false;

  @override
  void initState() {
    super.initState();
    _winController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _winBounce = CurvedAnimation(
      parent: _winController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _winController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GameBoard old) {
    super.didUpdateWidget(old);
    if (widget.game.gameWon && !_winAnimPlayed) {
      _winAnimPlayed = true;
      HapticFeedback.heavyImpact();
      _winController.forward();
    }
    if (!widget.game.gameWon) {
      _winAnimPlayed = false;
      _winController.reset();
    }
  }

  double get _cellSize => _cellSizeMap[widget.game.gridSize] ?? 48.0;
  double get _fontSize => _fontSizeMap[widget.game.gridSize] ?? 20.0;
  double get _gap => 3.0;
  double get _borderRadius => _cellSize >= 40 ? 10.0 : 8.0;

  bool _isHighlighted(int row, int col) {
    return widget.tutorialHighlight.any((c) => c.row == row && c.col == col);
  }

  bool _isHintSwapped(int row, int col) {
    return widget.game.hintSwappedCells.any((c) => c.row == row && c.col == col);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final gridSize = game.gridSize;
    final totalSize = gridSize * _cellSize + (gridSize + 1) * _gap;
    final colors = game.cellColors;

    // Make board responsive to screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth - 32; // 16px padding each side
    final scale = totalSize + 6 > maxWidth ? maxWidth / (totalSize + 6) : 1.0;

    return Center(
      child: AnimatedBuilder(
        animation: _winController,
        builder: (context, child) {
          final winScale = game.gameWon ? 1.0 + _winBounce.value * 0.03 : 1.0;
          return Transform.scale(
            scale: scale * winScale,
            child: child,
          );
        },
        child: Container(
          width: totalSize + 6,
          height: totalSize + 6,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: game.gameWon
                  ? AppColors.cellGreen.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
              width: 2.5,
            ),
            boxShadow: [
              if (game.gameWon)
                BoxShadow(
                  color: AppColors.cellGreen.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: SizedBox(
            width: totalSize,
            height: totalSize,
            child: Stack(
              children: [
                for (int r = 0; r < gridSize; r++)
                  for (int c = 0; c < gridSize; c++)
                    if (game.grid.isNotEmpty && game.grid[r][c] != 'X')
                      _GameCell(
                        key: ValueKey('$r,$c'),
                        row: r,
                        col: c,
                        letter: game.grid[r][c],
                        cellColor: colors['$r,$c'] ?? CellColor.grey,
                        isSelected: game.selectedCell != null &&
                            game.selectedCell!.row == r && game.selectedCell!.col == c,
                        isWon: game.gameWon,
                        isHighlighted: _isHighlighted(r, c),
                        isHintSwapped: _isHintSwapped(r, c),
                        cellSize: _cellSize,
                        fontSize: _fontSize,
                        gap: _gap,
                        borderRadius: _borderRadius,
                        onTap: () {
                          if (game.gameWon || widget.disableSwap) return;
                          if (colors['$r,$c'] == CellColor.green) return;
                          if (widget.tutorialHighlight.isNotEmpty && !_isHighlighted(r, c)) return;
                          HapticFeedback.lightImpact();
                          game.selectCell(r, c);
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual animated game cell.
class _GameCell extends StatelessWidget {
  final int row, col;
  final String letter;
  final CellColor cellColor;
  final bool isSelected;
  final bool isWon;
  final bool isHighlighted;
  final bool isHintSwapped;
  final double cellSize;
  final double fontSize;
  final double gap;
  final double borderRadius;
  final VoidCallback onTap;

  const _GameCell({
    super.key,
    required this.row,
    required this.col,
    required this.letter,
    required this.cellColor,
    required this.isSelected,
    required this.isWon,
    required this.isHighlighted,
    required this.isHintSwapped,
    required this.cellSize,
    required this.fontSize,
    required this.gap,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    switch (cellColor) {
      case CellColor.green:
        bgColor = isWon
            ? AppColors.cellGreen.withValues(alpha: 0.85)
            : AppColors.cellGreen;
      case CellColor.yellow:
        bgColor = AppColors.cellYellow;
      case CellColor.grey:
        bgColor = AppColors.cellGrey;
    }

    final x = gap + col * (cellSize + gap);
    final y = gap + row * (cellSize + gap);

    // Text color
    Color textColor;
    if (isWon) {
      textColor = Colors.white;
    } else if (cellColor == CellColor.yellow) {
      textColor = const Color(0xFF7A5C00);
    } else {
      textColor = Colors.white;
    }

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: isSelected
                ? Border.all(color: Colors.white, width: 3)
                : isHighlighted
                    ? Border.all(color: AppColors.gold, width: 3)
                    : isHintSwapped
                        ? Border.all(color: const Color(0xFFF59E0B), width: 2.5)
                        : null,
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              else if (isHighlighted)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              else if (cellColor == CellColor.green && !isWon)
                BoxShadow(
                  color: AppColors.cellGreen.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            child: Text(letter),
          ),
        ),
      ),
    );
  }
}
