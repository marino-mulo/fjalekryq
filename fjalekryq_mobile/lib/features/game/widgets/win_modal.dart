import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/constants/theme.dart';

class WinModal extends StatefulWidget {
  final String praise;
  final bool isTutorial;
  final int nextLevelNumber;
  final List<List<String>>? solvedGrid;
  final VoidCallback onNextLevel;
  final VoidCallback onGoHome;
  final VoidCallback? onSaveProgress;

  const WinModal({
    super.key,
    required this.praise,
    required this.isTutorial,
    required this.nextLevelNumber,
    this.solvedGrid,
    required this.onNextLevel,
    required this.onGoHome,
    this.onSaveProgress,
  });

  @override
  State<WinModal> createState() => _WinModalState();
}

class _WinModalState extends State<WinModal>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Animation<double> _staggered(double start, double end) {
    return CurvedAnimation(
      parent: _entryCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: Stack(
          children: [
            // Ambient radial glow
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final t = 0.22 + _pulseCtrl.value * 0.15;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.45),
                          radius: 1.0,
                          colors: [
                            AppColors.gold.withValues(alpha: t),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Title
                    _animatedChild(
                      anim: _staggered(0.0, 0.55),
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          colors: [AppColors.gold, Color(0xFFFFE27A)],
                        ).createShader(rect),
                        child: Text(
                          widget.isTutorial ? 'Bravo!' : 'Niveli Kaluar!',
                          textAlign: TextAlign.center,
                          style: AppFonts.nunito(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ).copyWith(
                            shadows: [
                              Shadow(
                                color: AppColors.gold.withValues(alpha: 0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      scale: true,
                    ),

                    // Flexible top spacer — pushes grid towards vertical center
                    const Spacer(flex: 2),

                    // Mini solved grid
                    if (!widget.isTutorial && widget.solvedGrid != null)
                      _animatedChild(
                        anim: _staggered(0.15, 0.7),
                        child: _buildGridPreview(
                            widget.solvedGrid!, size.width),
                        scale: true,
                      ),

                    const SizedBox(height: 20),

                    // Plain praise row
                    _animatedChild(
                      anim: _staggered(0.3, 0.8),
                      child: _buildPraiseRow(),
                    ),

                    // Save progress
                    if (widget.onSaveProgress != null) ...[
                      const SizedBox(height: 12),
                      _animatedChild(
                        anim: _staggered(0.5, 0.95),
                        child: _buildSaveProgressRow(),
                      ),
                    ],

                    // Flexible bottom spacer — pushes buttons to bottom
                    const Spacer(flex: 3),

                    // Bottom row: Kthehu në Fillim + Niveli N side-by-side
                    _animatedChild(
                      anim: _staggered(0.55, 1.0),
                      child: _buildBottomButtons(),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Entrance wrapper ──────────────────────────────────────────────────────
  Widget _animatedChild({
    required Animation<double> anim,
    required Widget child,
    bool scale = false,
  }) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final v = anim.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 24),
            child: scale
                ? Transform.scale(scale: 0.85 + 0.15 * v, child: child)
                : child,
          ),
        );
      },
    );
  }

  // ── Praise + coins row (plain, no banner background) ─────────────────────
  Widget _buildPraiseRow(int coins) {
    final hasCoins = coins > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.praise,
            style: AppFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasCoins) ...[
          const SizedBox(width: 14),
          if (_doubled) ...[
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.greenAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: AppColors.greenAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                '×2',
                style: AppFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.greenAccent,
                ),
              ),
            ),
          ],
          Text(
            '+$coins monedha',
            style: AppFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 6),
          const CoinIcon(size: 20),
        ],
      ],
    );
  }

  // ── Mini grid preview ─────────────────────────────────────────────────────
  Widget _buildGridPreview(List<List<String>> grid, double screenWidth) {
    final gridLen = grid.length;
    const gap = 2.0;
    final maxWidth = (screenWidth - 48 - 28).clamp(0.0, 260.0);
    final cellSize =
        ((maxWidth - (gridLen - 1) * gap) / gridLen).floorToDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 6),
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
                    color: isLetter
                        ? AppColors.greenAccent.withValues(alpha: 0.85)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isLetter
                      ? Center(
                          child: Text(
                            letter,
                            style: AppFonts.nunito(
                              fontSize:
                                  (cellSize * 0.38).clamp(9.0, 14.0),
                              fontWeight: FontWeight.w900,
                              color: AppColors.backgroundDark,
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

  // ── Double-coins banner ───────────────────────────────────────────────────
  Widget _buildDoubleCoinsBanner() {
    final loading = _adLoading == _AdLoading.doubleCoins;
    return GestureDetector(
      onTap: loading ? null : _watchDoubleCoinsAd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.purpleAccent.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const AnimatedIconFx(
              Icons.videocam_rounded,
              style: IconFxStyle.pulse,
              color: Color(0xFFC084FC),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dyfisho monedhat · +${widget.coinsEarned * 2} falas',
                style: AppFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE9D5FF),
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.purpleAccent.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.purpleAccent.withValues(alpha: 0.55)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE9D5FF),
                      ),
                    )
                  : Text(
                      'Shiko · ×2',
                      style: AppFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE9D5FF),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Save progress row ─────────────────────────────────────────────────────
  Widget _buildSaveProgressRow() {
    return GestureDetector(
      onTap: widget.onSaveProgress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
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

  // ── Bottom row: Kthehu (secondary) + Niveli N (primary gold) ─────────────
  Widget _buildBottomButtons() {
    final nextLabel = widget.isTutorial
        ? 'Fillo Lojën'
        : 'Niveli ${widget.nextLevelNumber}';

    // Tutorial: only next button (no home in the tutorial context).
    if (widget.isTutorial) {
      return _primaryButton(label: nextLabel, onTap: widget.onNextLevel);
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _secondaryButton(
            label: 'Kthehu në Fillim',
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onGoHome();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _primaryButton(label: nextLabel, onTap: widget.onNextLevel),
        ),
      ],
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gold, Color(0xFFFFD86B)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.backgroundDark,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
