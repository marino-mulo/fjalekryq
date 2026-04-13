import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Fixed seed for deterministic tile layout across all screens.
const _tileSeed = 42;
const _tileLetters = 'ABCÇDEHIMNOPRSTUVXZË';
const _tileColors = [AppColors.gold, AppColors.cellGreen, AppColors.cellGrey];

/// Data class for one background tile.
class _BgTile {
  final int id;
  final String letter;
  double x, y; // percentage-based positions (0-100)
  final Color color;

  _BgTile({
    required this.id,
    required this.letter,
    required this.x,
    required this.y,
    required this.color,
  });
}

/// 15 animated background tiles (3 rows × 5 cols) shared across all screens.
///
/// Uses a fixed seed so letters and initial positions are identical everywhere.
/// When [animate] is true, tiles swap positions every 3 seconds with easeOutBack.
class BackgroundTiles extends StatefulWidget {
  /// Whether to animate (swap) tiles periodically. Default true.
  final bool animate;

  const BackgroundTiles({super.key, this.animate = true});

  @override
  State<BackgroundTiles> createState() => _BackgroundTilesState();
}

class _BackgroundTilesState extends State<BackgroundTiles> {
  late List<_BgTile> _tiles;
  Timer? _swapTimer;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _tiles = _createTiles();
    if (widget.animate) {
      // Delay start to let the UI settle
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _swapTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
          if (!mounted) return;
          final i = _rng.nextInt(_tiles.length);
          var j = _rng.nextInt(_tiles.length - 1);
          if (j >= i) j++;
          setState(() {
            final tmpX = _tiles[i].x;
            final tmpY = _tiles[i].y;
            _tiles[i].x = _tiles[j].x;
            _tiles[i].y = _tiles[j].y;
            _tiles[j].x = tmpX;
            _tiles[j].y = tmpY;
          });
        });
      });
    }
  }

  @override
  void dispose() {
    _swapTimer?.cancel();
    super.dispose();
  }

  /// Deterministic tile generation with fixed seed.
  static List<_BgTile> _createTiles() {
    final rng = Random(_tileSeed);
    final tiles = <_BgTile>[];
    final rows = [18.0, 45.0, 75.0];
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < 5; c++) {
        final i = r * 5 + c;
        tiles.add(_BgTile(
          id: i,
          letter: _tileLetters[rng.nextInt(_tileLetters.length)],
          x: 6 + c * 20 + (rng.nextDouble() - 0.5) * 8,
          y: rows[r] + (rng.nextDouble() - 0.5) * 10,
          color: _tileColors[i % 3],
        ));
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Stack(
      children: _tiles.map((tile) {
        final child = Opacity(
          opacity: 0.72,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tile.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              tile.letter,
              style: AppFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );

        if (widget.animate) {
          return AnimatedPositioned(
            key: ValueKey(tile.id),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutBack,
            left: tile.x / 100 * screenSize.width,
            top: tile.y / 100 * screenSize.height,
            child: child,
          );
        } else {
          return Positioned(
            key: ValueKey(tile.id),
            left: tile.x / 100 * screenSize.width,
            top: tile.y / 100 * screenSize.height,
            child: child,
          );
        }
      }).toList(),
    );
  }
}
