import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/coin_service.dart';
import '../../../shared/constants/theme.dart';
import '../../../shared/widgets/coin_badge.dart';
import '../../../shared/widgets/shiko_button.dart';

class FailModal extends StatefulWidget {
  final AdService adService;
  final CoinService coinService;
  /// Snapshot of the grid at the moment of failure, used for the thumbnail.
  final List<List<String>>? currentGrid;
  final Future<void> Function() onWatchAd;
  final VoidCallback onBuyMoves;
  final VoidCallback onRestart;

  const FailModal({
    super.key,
    required this.adService,
    required this.coinService,
    this.currentGrid,
    required this.onWatchAd,
    required this.onBuyMoves,
    required this.onRestart,
  });

  @override
  State<FailModal> createState() => _FailModalState();
}

class _FailModalState extends State<FailModal> {
  bool _loadingAd = false;
  int _adRemaining = 5;

  @override
  void initState() {
    super.initState();
    _loadRemaining();
  }

  Future<void> _loadRemaining() async {
    final r = await widget.adService.remainingToday(AdType.continueAfterLoss);
    if (mounted) setState(() => _adRemaining = r);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canAfford30 = widget.coinService.canAfford(30);
    final canWatchAd  = _adRemaining > 0;
    final size        = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Gradient background (warm crimson) ───────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
                colors: [
                  Color(0xFFE53935), // bright red
                  Color(0xFFC62828), // crimson
                  Color(0xFF7B0000), // deep dark red
                ],
              ),
            ),
          ),
          // ── Sunburst rays ────────────────────────────────────────────────
          CustomPaint(
            size: Size(size.width, size.height),
            painter: const _FailSunburstPainter(),
          ),
          // ── Scrollable content ───────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Lëvizjet Mbaruan!',
                    textAlign: TextAlign.center,
                    style: AppFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vazhdo ose fillo sërish.',
                    style: AppFonts.quicksand(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Mini grid preview (current incomplete state)
                  if (widget.currentGrid != null) ...[
                    _buildGridPreview(widget.currentGrid!, size.width),
                    const SizedBox(height: 20),
                  ],

                  // ── Watch Ad — featured CTA ──────────────────────────────
                  if (canWatchAd) ...[
                    _buildWatchAdTile(),
                    const SizedBox(height: 12),
                  ],

                  // ── Buy moves with coins — secondary option ──────────────
                  _buildBuyMovesTile(canAfford30),

                  const SizedBox(height: 32),

                  // ── Restart — primary button ─────────────────────────────
                  _buildRestartButton(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Incomplete grid thumbnail ──────────────────────────────────────────────

  Widget _buildGridPreview(List<List<String>> grid, double screenWidth) {
    final gridLen = grid.length;
    const gap     = 2.0;
    final maxWidth = (screenWidth - 48 - 28).clamp(0.0, 280.0);
    final cellSize = ((maxWidth - (gridLen - 1) * gap) / gridLen).floorToDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.28), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(gridLen, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row < gridLen - 1 ? gap : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(gridLen, (col) {
                final letter = row < grid.length && col < grid[row].length
                    ? grid[row][col]
                    : 'X';
                final isLetter = letter != 'X';
                return Container(
                  width: cellSize,
                  height: cellSize,
                  margin:
                      EdgeInsets.only(right: col < gridLen - 1 ? gap : 0),
                  decoration: BoxDecoration(
                    // Slightly warm-tinted white for the fail state
                    color: isLetter
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isLetter
                      ? Center(
                          child: Text(
                            letter,
                            style: AppFonts.nunito(
                              fontSize: (cellSize * 0.38).clamp(9.0, 14.0),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF7B0000),
                            ),
                          ),
                        )
                      : null,
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  // ── Watch Ad featured tile ─────────────────────────────────────────────────

  Widget _buildWatchAdTile() {
    return GestureDetector(
      onTap: _loadingAd
          ? null
          : () async {
              setState(() => _loadingAd = true);
              await widget.onWatchAd();
              // onWatchAd already pops the modal on success; if still mounted
              // (ad cancelled / failed), reset state.
              if (mounted) setState(() => _loadingAd = false);
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          // Bright highlight so it reads as the primary action
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.38), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.purpleAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.purpleAccent.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: Color(0xFFE040FB), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shiko Reklamë · +5 Lëvizje',
                    style: AppFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Vazhdo nivelin aktual falas',
                    style: AppFonts.quicksand(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShikoButton(
              size: ShikoSize.medium,
              loading: _loadingAd,
              badge: '+5',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Buy moves tile ─────────────────────────────────────────────────────────

  Widget _buildBuyMovesTile(bool canAfford) {
    return GestureDetector(
      onTap: canAfford
          ? () {
              HapticFeedback.selectionClick();
              widget.onBuyMoves();
            }
          : null,
      child: Opacity(
        opacity: canAfford ? 1.0 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(11),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFFDD835), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bli 5 Lëvizje',
                      style: AppFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      canAfford
                          ? 'Bilanci: ${widget.coinService.coins} monedha'
                          : 'Monedha të pamjaftueshme',
                      style: AppFonts.quicksand(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '30',
                      style: AppFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFDD835),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Restart button ─────────────────────────────────────────────────────────

  Widget _buildRestartButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onRestart();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded,
                color: const Color(0xFFC62828), size: 22),
            const SizedBox(width: 8),
            Text(
              'Fillo nga Fillimi',
              style: AppFonts.nunito(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFC62828),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sunburst painter (red palette) ────────────────────────────────────────────

class _FailSunburstPainter extends CustomPainter {
  const _FailSunburstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const rays   = 18;
    final cx     = size.width / 2;
    final cy     = size.height * 0.26;
    final radius = size.longestSide * 1.55;
    final paint  = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < rays; i++) {
      final a1 = (i * 2 / rays) * math.pi;
      final a2 = ((i * 2 + 1) / rays) * math.pi;
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + radius * math.cos(a1), cy + radius * math.sin(a1))
        ..lineTo(cx + radius * math.cos(a2), cy + radius * math.sin(a2))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
