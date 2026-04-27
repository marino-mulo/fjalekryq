import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/services/game_service.dart';
import '../../../core/services/audio_service.dart';
import '../../../shared/constants/theme.dart';
import '../../tutorial/tutorial_finger.dart';

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

  // Swap fly-in animation tracking
  List<SwapAnimation>? _flyingCells;
  // Track the identity of the last swap we processed to avoid re-triggering
  int _lastSwapId = -1;
  int _swapCounter = 0;

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

    // Detect new swap animation - use totalSwapCount as identity
    final lastSwap = widget.game.lastSwap;
    final currentId = widget.game.totalSwapCount + widget.game.hintCount;
    if (lastSwap != null && lastSwap.isNotEmpty && currentId != _lastSwapId) {
      _lastSwapId = currentId;
      _swapCounter++;
      final thisSwap = _swapCounter;
      setState(() => _flyingCells = lastSwap);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _swapCounter == thisSwap) {
          setState(() => _flyingCells = null);
        }
      });
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

  /// Get fly animation data for a specific cell, if it's currently flying.
  SwapAnimation? _getFly(int row, int col) {
    if (_flyingCells == null) return null;
    for (final f in _flyingCells!) {
      if (f.row == row && f.col == col) return f;
    }
    return null;
  }

  /// Calculate pixel X for a column.
  double _cellX(int col) => _gap + col * (_cellSize + _gap);
  /// Calculate pixel Y for a row.
  double _cellY(int row) => _gap + row * (_cellSize + _gap);

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

    return AnimatedBuilder(
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
          // Glass tint that lets the shared AppBackground gradient show
          // through — no more solid navy rectangle fighting the backdrop.
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: game.gameWon
                ? AppColors.cellGreen.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            if (game.gameWon)
              BoxShadow(
                color: AppColors.cellGreen.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 4,
              ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: SizedBox(
          width: totalSize,
          height: totalSize,
          child: Stack(
            clipBehavior: Clip.none,
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
                      fly: _getFly(r, c),
                      cellSize: _cellSize,
                      fontSize: _fontSize,
                      gap: _gap,
                      borderRadius: _borderRadius,
                      cellX: _cellX,
                      cellY: _cellY,
                      onTap: () {
                        if (game.gameWon || widget.disableSwap) return;
                        if (colors['$r,$c'] == CellColor.green) return;
                        if (widget.tutorialHighlight.isNotEmpty && !_isHighlighted(r, c)) return;
                        HapticFeedback.lightImpact();
                        final audio = context.read<AudioService>();
                        if (game.selectedCell != null && !(game.selectedCell!.row == r && game.selectedCell!.col == c)) {
                          audio.play(Sfx.swap);
                        } else {
                          audio.play(Sfx.tap);
                        }
                        game.selectCell(r, c);
                      },
                    ),
              // Tutorial: animated pointing finger floating just above each
              // highlighted cell. Painted on top of the cells so it stays
              // visible regardless of cell colour and tracks the cell's
              // pixel position automatically.
              for (final hl in widget.tutorialHighlight)
                Positioned(
                  left: _cellX(hl.col) + (_cellSize - 28) / 2,
                  top: _cellY(hl.row) - 30,
                  child: const IgnorePointer(
                    child: TutorialFinger(
                      direction: FingerDirection.down,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual animated game cell with fly-in swap animation.
class _GameCell extends StatefulWidget {
  final int row, col;
  final String letter;
  final CellColor cellColor;
  final bool isSelected;
  final bool isWon;
  final bool isHighlighted;
  final bool isHintSwapped;
  final SwapAnimation? fly;
  final double cellSize;
  final double fontSize;
  final double gap;
  final double borderRadius;
  final double Function(int) cellX;
  final double Function(int) cellY;
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
    required this.fly,
    required this.cellSize,
    required this.fontSize,
    required this.gap,
    required this.borderRadius,
    required this.cellX,
    required this.cellY,
    required this.onTap,
  });

  @override
  State<_GameCell> createState() => _GameCellState();
}

class _GameCellState extends State<_GameCell>
    with TickerProviderStateMixin {
  AnimationController? _flyController;
  Animation<double>? _flyProgress;

  // Fly offsets (from old position)
  double _fromDx = 0;
  double _fromDy = 0;
  bool _hasActiveFly = false;

  @override
  void didUpdateWidget(_GameCell old) {
    super.didUpdateWidget(old);
    // New fly animation triggered
    if (widget.fly != null && !_hasActiveFly) {
      _startFly(widget.fly!);
    } else if (widget.fly == null && _hasActiveFly) {
      _stopFly();
    }
  }

  void _startFly(SwapAnimation fly) {
    _fromDx = widget.cellX(fly.fromCol) - widget.cellX(fly.col);
    _fromDy = widget.cellY(fly.fromRow) - widget.cellY(fly.row);
    _hasActiveFly = true;

    _flyController?.dispose();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flyProgress = CurvedAnimation(
      parent: _flyController!,
      curve: Curves.easeOutBack,
    );
    _flyController!.forward();
  }

  void _stopFly() {
    _hasActiveFly = false;
    _flyController?.stop();
    _flyController?.dispose();
    _flyController = null;
    _flyProgress = null;
  }

  @override
  void dispose() {
    _flyController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    switch (widget.cellColor) {
      case CellColor.green:
        bgColor = widget.isWon
            ? AppColors.cellGreen.withValues(alpha: 0.85)
            : AppColors.cellGreen;
      case CellColor.yellow:
        bgColor = AppColors.cellYellow;
      case CellColor.grey:
        bgColor = AppColors.cellGrey;
    }

    final x = widget.gap + widget.col * (widget.cellSize + widget.gap);
    final y = widget.gap + widget.row * (widget.cellSize + widget.gap);

    Color textColor;
    if (widget.isWon) {
      textColor = Colors.white;
    } else if (widget.cellColor == CellColor.yellow) {
      textColor = const Color(0xFF7A5C00);
    } else {
      textColor = Colors.white;
    }

    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: widget.cellSize,
      height: widget.cellSize,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.isSelected
            ? Border.all(color: Colors.white, width: 3)
            : widget.isHighlighted
                ? Border.all(color: AppColors.gold, width: 3)
                : widget.isHintSwapped
                    ? Border.all(color: const Color(0xFFF59E0B), width: 2.5)
                    : null,
        boxShadow: [
          if (widget.isSelected)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else if (widget.isHighlighted)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else if (widget.cellColor == CellColor.green && !widget.isWon)
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
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
        child: Text(widget.letter),
      ),
    );

    // Wrap with fly-in animation if active
    if (_hasActiveFly && _flyController != null && _flyProgress != null) {
      cell = AnimatedBuilder(
        animation: _flyProgress!,
        builder: (context, child) {
          final t = _flyProgress!.value;
          final dx = _fromDx * (1 - t);
          final dy = _fromDy * (1 - t);
          final s = 0.65 + 0.35 * t;
          final opacity = (0.6 + 0.4 * t).clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: s,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            ),
          );
        },
        child: cell,
      );
    }

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: widget.onTap,
        child: cell,
      ),
    );
  }
}
