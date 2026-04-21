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

class _WinModalState extends State<WinModal> with SingleTickerProviderStateMixin {
  _AdLoading _adLoading = _AdLoading.none;
  bool _doubled = false;
  late AnimationController _confettiCtrl;
  late List<_WinParticle> _particles;

  @override
  void initState() {
    super.initState();
    _doubled = widget.winCoinsDoubled;
    _particles = _buildParticles();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    // Start confetti shortly after the modal slides in
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _confettiCtrl.forward();
    });
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
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
    final showDoubleAd = !widget.isTutorial && widget.coinsEarned > 0 && !_doubled;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Dark navy gradient (matches app theme) ───────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
                colors: [
                  Color(0xFF1A2C52), // dark navy blue
                  Color(0xFF0F1C3A), // deeper navy
                  Color(0xFF080D1C), // near-black
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
                  const SizedBox(height: 28),

                  // Praise + title
                  Text(
                    widget.praise,
                    textAlign: TextAlign.center,
                    style: AppFonts.nunito(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isTutorial) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Niveli Kaluar!',
                      textAlign: TextAlign.center,
                      style: AppFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Mini solved grid
                  if (!widget.isTutorial && widget.solvedGrid != null) ...[
                    _buildGridPreview(widget.solvedGrid!, size.width),
                    const SizedBox(height: 18),
                  ],

                  // Coins earned
                  _buildCoinsCard(),

                  // Double coins ad
                  if (showDoubleAd) ...[
                    const SizedBox(height: 10),
                    _buildDoubleCoinsOffer(),
                  ],

                  // Save progress
                  if (widget.onSaveProgress != null) ...[
                    const SizedBox(height: 10),
                    _buildSaveProgressRow(),
                  ],

                  const SizedBox(height: 28),

                  // Next Level button
                  _buildNextLevelButton(),
                  const SizedBox(height: 14),

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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // ── Confetti overlay ─────────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _confettiCtrl.value,
                    particles: _particles,
                  ),
                ),
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
    final maxWidth = (screenWidth - 48 - 28).clamp(0.0, 300.0);
    final cellSize = ((maxWidth - (gridLen - 1) * gap) / gridLen).floorToDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
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
                  margin: EdgeInsets.only(right: col < gridLen - 1 ? gap : 0),
                  decoration: BoxDecoration(
                    color: isLetter
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isLetter
                      ? Center(
                          child: Text(
                            letter,
                            style: AppFonts.nunito(
                              fontSize: (cellSize * 0.38).clamp(9.0, 14.0),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F1C3A),
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

  // ── Coins earned card ──────────────────────────────────────────────────────

  Widget _buildCoinsCard() {
    final coins = _doubled ? widget.coinsEarned * 2 : widget.coinsEarned;
    if (coins <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, color: Color(0xFFFDD835), size: 22),
          const SizedBox(width: 10),
          Text(
            '+$coins monedha',
            style: AppFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFDD835),
            ),
          ),
          if (_doubled) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.45)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.purpleAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.videocam_rounded, color: Color(0xFFC084FC), size: 20),
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
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '+${widget.coinsEarned * 2} monedha falas',
                    style: AppFonts.quicksand(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4285F4).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'G',
              style: TextStyle(
                fontSize: 15,
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
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          widget.isTutorial ? 'Fillo Lojën' : 'Niveli ${widget.nextLevelNumber}',
          textAlign: TextAlign.center,
          style: AppFonts.nunito(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F1C3A),
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
    const rays = 20;
    final cx = size.width / 2;
    final cy = size.height * 0.28;
    final radius = size.longestSide * 1.6;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
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

// ── Confetti ───────────────────────────────────────────────────────────────────

class _WinParticle {
  final double x, vy, vx, freq, phase, amplitude, size;
  final Color color;
  final bool isRect;
  const _WinParticle({
    required this.x, required this.vy, required this.vx,
    required this.freq, required this.phase, required this.amplitude,
    required this.color, required this.size, required this.isRect,
  });
}

List<_WinParticle> _buildParticles() {
  final rng = math.Random(7);
  const colors = [
    Color(0xFFFFBA27), Color(0xFF3B82F6), Color(0xFF4ADE80),
    Color(0xFFC084FC), Color(0xFFFF6B35), Color(0xFFFFFFFF),
    Color(0xFFFBBF24), Color(0xFF60A5FA),
  ];
  return List.generate(60, (_) => _WinParticle(
    x: rng.nextDouble(),
    vy: 0.5 + rng.nextDouble() * 0.65,
    vx: (rng.nextDouble() - 0.5) * 0.14,
    freq: 2 + rng.nextDouble() * 4,
    phase: rng.nextDouble() * 6.28,
    amplitude: 0.02 + rng.nextDouble() * 0.04,
    color: colors[rng.nextInt(colors.length)],
    size: 6 + rng.nextDouble() * 8,
    isRect: rng.nextBool(),
  ));
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_WinParticle> particles;
  _ConfettiPainter({required this.progress, required this.particles}) : super();

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    for (final p in particles) {
      final px = (p.x + p.vx * progress + p.amplitude * math.sin(p.freq * progress * math.pi * 2 + p.phase)) * size.width;
      final py = -30.0 + p.vy * progress * size.height * 1.1;
      final alpha = progress < 0.75 ? 1.0 : (1.0 - progress) / 0.25;
      if (alpha <= 0) continue;
      final paint = Paint()..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(progress * p.freq * math.pi);
      if (p.isRect) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
