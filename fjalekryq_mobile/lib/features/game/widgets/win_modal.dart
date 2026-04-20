import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/constants/theme.dart';
import '../../../shared/widgets/coin_badge.dart';
import '../../../shared/widgets/shiko_button.dart';

enum _AdLoading { none, doubleCoins }

class WinModal extends StatefulWidget {
  final String praise;
  final int coinsEarned;
  final bool winCoinsDoubled;
  final bool isTutorial;
  final int nextLevelNumber;
  final List<List<String>>? solvedGrid;
  final Future<void> Function() onDoubleCoins;
  final VoidCallback onNextLevel;
  final VoidCallback onGoHome;
  final VoidCallback? onSaveProgress;

  const WinModal({
    super.key,
    required this.praise,
    required this.coinsEarned,
    required this.winCoinsDoubled,
    required this.isTutorial,
    required this.nextLevelNumber,
    this.solvedGrid,
    required this.onDoubleCoins,
    required this.onNextLevel,
    required this.onGoHome,
    this.onSaveProgress,
  });

  @override
  State<WinModal> createState() => _WinModalState();
}

class _WinModalState extends State<WinModal> {
  _AdLoading _adLoading = _AdLoading.none;
  bool _doubled = false;

  @override
  void initState() {
    super.initState();
    _doubled = widget.winCoinsDoubled;
  }

  Future<void> _watchDoubleCoinsAd() async {
    if (_adLoading != _AdLoading.none) return;
    setState(() => _adLoading = _AdLoading.doubleCoins);
    await widget.onDoubleCoins();
    if (mounted) {
      setState(() {
        _adLoading = _AdLoading.none;
        _doubled = true;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showDoubleAd = !widget.isTutorial &&
        widget.coinsEarned > 0 &&
        !_doubled;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
                colors: [
                  Color(0xFF2196F3), // sky blue
                  Color(0xFF1565C0), // royal blue
                  Color(0xFF0D3B8E), // deep blue
                ],
              ),
            ),
          ),
          // ── Sunburst rays ────────────────────────────────────────────────
          CustomPaint(
            size: Size(size.width, size.height),
            painter: const _SunburstPainter(),
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
                    widget.isTutorial ? 'Bravo!' : 'Niveli Kaluar!',
                    textAlign: TextAlign.center,
                    style: AppFonts.nunito(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Mini solved grid
                  if (!widget.isTutorial && widget.solvedGrid != null) ...[
                    _buildGridPreview(widget.solvedGrid!, size.width),
                    const SizedBox(height: 20),
                  ],

                  // Stats card
                  _buildStatsCard(),

                  // Double coins ad
                  if (showDoubleAd) ...[
                    const SizedBox(height: 12),
                    _buildDoubleCoinsOffer(),
                  ],

                  // Save progress
                  if (widget.onSaveProgress != null) ...[
                    const SizedBox(height: 12),
                    _buildSaveProgressRow(),
                  ],

                  const SizedBox(height: 32),

                  // Next Level button
                  _buildNextLevelButton(),
                  const SizedBox(height: 16),

                  // Go home text link
                  if (!widget.isTutorial)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onGoHome();
                      },
                      child: Text(
                        'Kthehu në Fillim',
                        style: AppFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mini grid preview ──────────────────────────────────────────────────────

  Widget _buildGridPreview(List<List<String>> grid, double screenWidth) {
    final gridLen = grid.length;
    const gap = 2.0;
    // Fit the grid within the available width
    final maxWidth = (screenWidth - 48 - 28).clamp(0.0, 280.0);
    final cellSize = ((maxWidth - (gridLen - 1) * gap) / gridLen).floorToDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
                final letter =
                    row < grid.length && col < grid[row].length
                        ? grid[row][col]
                        : 'X';
                final isLetter = letter != 'X';
                return Container(
                  width: cellSize,
                  height: cellSize,
                  margin: EdgeInsets.only(right: col < gridLen - 1 ? gap : 0),
                  decoration: BoxDecoration(
                    color: isLetter
                        ? Colors.white.withValues(alpha: 0.92)
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
                              color: const Color(0xFF0D47A1),
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

  // ── Stats card ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    final coins = _doubled ? widget.coinsEarned * 2 : widget.coinsEarned;
    final hasCoins = coins > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
      ),
      child: Column(
        children: [
          // Coins row
          if (hasCoins)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  Text(
                    'Monedha',
                    style: AppFonts.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const Spacer(),
                  if (_doubled) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFF4CAF50).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '×2',
                        style: AppFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF69F0AE),
                        ),
                      ),
                    ),
                  ],
                  Text(
                    '+$coins',
                    style: AppFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFDD835),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CoinIcon(size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Double coins ad tile ───────────────────────────────────────────────────

  Widget _buildDoubleCoinsOffer() {
    return GestureDetector(
      onTap: _adLoading != _AdLoading.none ? null : _watchDoubleCoinsAd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.purpleAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: AppColors.purpleAccent.withValues(alpha: 0.4)),
              ),
              child:
                  const Icon(Icons.videocam, color: Color(0xFFC084FC), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dyfisho Monedhat',
                    style: AppFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  Text(
                    '+${widget.coinsEarned * 2} monedha falas',
                    style: AppFonts.quicksand(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            ShikoButton(
              size: ShikoSize.medium,
              loading: _adLoading == _AdLoading.doubleCoins,
              badge: '×2',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Save progress row ──────────────────────────────────────────────────────

  Widget _buildSaveProgressRow() {
    return GestureDetector(
      onTap: widget.onSaveProgress,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4285F4).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF4285F4).withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'G',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4285F4),
                height: 1.3,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ruaj Progresin · +100 monedha',
              style: AppFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF93C5FD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Next level button ──────────────────────────────────────────────────────

  Widget _buildNextLevelButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onNextLevel();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Text(
          widget.isTutorial ? 'Fillo Lojën' : 'Niveli ${widget.nextLevelNumber}',
          textAlign: TextAlign.center,
          style: AppFonts.nunito(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }
}

// ── Sunburst painter ───────────────────────────────────────────────────────────

class _SunburstPainter extends CustomPainter {
  const _SunburstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const rays   = 18;
    final cx     = size.width / 2;
    final cy     = size.height * 0.26;
    final radius = size.longestSide * 1.55;
    final paint  = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
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
