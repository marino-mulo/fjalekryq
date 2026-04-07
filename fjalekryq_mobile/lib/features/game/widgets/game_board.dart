import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/game_service.dart';
import '../../../shared/constants/theme.dart';

/// Cell size lookup to keep total board fitting the screen width.
const _cellSizeMap = {5: 64.0, 6: 56.0, 7: 50.0, 8: 44.0, 9: 38.0, 10: 34.0, 11: 31.0, 12: 28.0, 13: 26.0};
const _fontSizeMap = {5: 28.0, 6: 24.0, 7: 21.0, 8: 18.0, 9: 16.0, 10: 14.0, 11: 12.0, 12: 11.0, 13: 10.0};

/// The game board rendered as a grid of tappable cells.
class GameBoard extends StatelessWidget {
  final GameService game;
  final List<({int row, int col})> tutorialHighlight;
  final bool disableSwap;

  const GameBoard({
    super.key,
    required this.game,
    this.tutorialHighlight = const [],
    this.disableSwap = false,
  });

  double get _cellSize => _cellSizeMap[game.gridSize] ?? 48.0;
  double get _fontSize => _fontSizeMap[game.gridSize] ?? 20.0;
  double get _gap => 3.0;
  double get _borderRadius => _cellSize >= 40 ? 10.0 : 8.0;

  bool _isHighlighted(int row, int col) {
    return tutorialHighlight.any((c) => c.row == row && c.col == col);
  }

  bool _isHintSwapped(int row, int col) {
    return game.hintSwappedCells.any((c) => c.row == row && c.col == col);
  }

  @override
  Widget build(BuildContext context) {
    final gridSize = game.gridSize;
    final totalSize = gridSize * _cellSize + (gridSize + 1) * _gap;
    final colors = game.cellColors;

    return Center(
      child: Container(
        width: totalSize + 6,
        height: totalSize + 6,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2.5),
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
                    _buildCell(r, c, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, Map<String, CellColor> colors) {
    final letter = game.grid[row][col];
    final colorKey = '$row,$col';
    final cellColor = colors[colorKey] ?? CellColor.grey;
    final isSelected = game.selectedCell != null &&
        game.selectedCell!.row == row && game.selectedCell!.col == col;
    final isLocked = cellColor == CellColor.green;
    final isWon = game.gameWon;
    final highlighted = _isHighlighted(row, col);
    final hintSwapped = _isHintSwapped(row, col);

    Color bgColor;
    switch (cellColor) {
      case CellColor.green:
        bgColor = isWon ? AppColors.cellGreen.withValues(alpha: 0.9) : AppColors.cellGreen;
      case CellColor.yellow:
        bgColor = AppColors.cellYellow;
      case CellColor.grey:
        bgColor = AppColors.cellGrey;
    }

    final x = _gap + col * (_cellSize + _gap);
    final y = _gap + row * (_cellSize + _gap);

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () {
          if (game.gameWon || disableSwap || isLocked) return;
          if (tutorialHighlight.isNotEmpty && !highlighted) return;
          HapticFeedback.lightImpact();
          game.selectCell(row, col);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(_borderRadius),
            border: isSelected
                ? Border.all(color: Colors.white, width: 3)
                : highlighted
                    ? Border.all(color: AppColors.gold, width: 3.5)
                    : hintSwapped
                        ? Border.all(color: const Color(0xFFF59E0B), width: 3)
                        : null,
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 8)]
                : highlighted
                    ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 8)]
                    : null,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w800,
              color: isWon
                  ? Colors.white
                  : cellColor == CellColor.yellow
                      ? const Color(0xFF7A5C00)
                      : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
