import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'background_tiles.dart';

/// Unified app background used across every full-page screen.
///
/// Layers (bottom → top):
///   1. Shared gradient (matches the web design)
///   2. Soft golden radial glow
///   3. Two decorative "solved puzzle" mini-grids rotated -70° in the
///      top-left and bottom-right corners
///   4. Optional animated [BackgroundTiles] (opt-in per screen)
///   5. The page's [child] content
///
/// Wrap a screen body (not the `Scaffold` itself) with this widget and set
/// `Scaffold(backgroundColor: Colors.transparent)` so the gradient shows
/// through.
class AppBackground extends StatelessWidget {
  final Widget child;

  /// When true, the shared animated [BackgroundTiles] layer is rendered on
  /// top of the corner decorations. Used by home / onboarding / splash.
  final bool showAnimatedTiles;

  /// When false, the two decorative "solved puzzle" mini-grids in the
  /// top-left / bottom-right corners are skipped. Set this on the
  /// publisher splash so the LojraLogjike branding stands alone, with
  /// no Fjalekryq-themed crossword decoration leaking through.
  final bool showCornerPuzzles;

  const AppBackground({
    super.key,
    required this.child,
    this.showAnimatedTiles = false,
    this.showCornerPuzzles = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 1. Base gradient — single source of truth for every page.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0C1F4A),
                  Color(0xFF123B86),
                  Color(0xFF07152F),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
        ),

        // 2. Soft golden radial glow, positioned relative to screen.
        Positioned(
          top: size.height * 0.33,
          left: size.width * 0.15,
          child: IgnorePointer(
            child: Container(
              width: size.width * 0.7,
              height: size.height * 0.42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(200),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFBA27).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // 3a. Top-left decorative solved puzzle, tilted -70° (diagonal).
        if (showCornerPuzzles)
          const Positioned(
            top: 80,
            left: -110,
            child: IgnorePointer(
              child: _CornerPuzzle(
                grid: _topLeftGrid,
                rotationDegrees: -70,
                opacity: 0.07,
              ),
            ),
          ),

        // 3b. Bottom-right decorative solved puzzle, tilted -70° (diagonal).
        // Pushed further down so it peeks in from the bottom corner again.
        if (showCornerPuzzles)
          const Positioned(
            bottom: -40,
            right: -110,
            child: IgnorePointer(
              child: _CornerPuzzle(
                grid: _bottomRightGrid,
                rotationDegrees: -70,
                opacity: 0.07,
              ),
            ),
          ),

        // 4. Optional animated tiles (shared across home/onboarding).
        if (showAnimatedTiles) const BackgroundTiles(animate: true),

        // 5. Page content.
        child,
      ],
    );
  }
}

// ─── Corner puzzle decoration ────────────────────────────────────────────────

/// One cell in a decorative mini-puzzle. `null` = void/black cell.
typedef _Cell = String?;

/// 6x6 "solved" mini-crossword for the top-left corner.
/// Dots (null) are void cells, letters are "solved" cells.
const List<List<_Cell>> _topLeftGrid = [
  [null, 'M', null, null, null, null],
  ['B',  'O',  'R',  'A', null, null],
  [null, 'T',  null, 'L', null, null],
  ['D',  'E',  'T',  'I', null, null],
  [null, null, null, null, null, null],
  [null, null, null, null, null, null],
];

/// 6x6 "solved" mini-crossword for the bottom-right corner.
const List<List<_Cell>> _bottomRightGrid = [
  [null, null, null, null, null, null],
  [null, null, null, null, null, null],
  [null, null, 'F',  'J',  'A',  'L'],
  [null, null, null, 'A',  null, null],
  [null, null, 'K',  'O',  'H',  'A'],
  [null, null, null, 'N',  null, null],
];

class _CornerPuzzle extends StatelessWidget {
  final List<List<_Cell>> grid;
  final double rotationDegrees;
  final double opacity;

  const _CornerPuzzle({
    required this.grid,
    required this.rotationDegrees,
    this.opacity = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    final radians = rotationDegrees * math.pi / 180.0;
    return Transform.rotate(
      angle: radians,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: grid
              .map((row) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: row.map(_buildCell).toList(),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCell(_Cell value) {
    const size = 58.0;
    const gap = 4.0;

    if (value == null) {
      // Void / blacked-out crossword cell.
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(gap / 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    // Solved letter cell — green, consistent with the in-game correct state.
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(gap / 2),
      decoration: BoxDecoration(
        color: AppColors.cellGreen,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: AppFonts.nunito(
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
