import 'package:flutter/material.dart';
import '../../../shared/constants/theme.dart';
import '../../../shared/widgets/coin_badge.dart';
import '../../../shared/widgets/shiko_button.dart';

/// Tracks which ad slot is currently loading in the win modal.
enum _AdLoading { none, doubleCoins }

class WinModal extends StatefulWidget {
  final int stars;
  final String praise;
  final int coinsEarned;
  final bool winCoinsDoubled;
  final bool isTutorial;
  final bool isReplayRun;
  final int nextLevelNumber;
  final Future<void> Function() onDoubleCoins;
  final VoidCallback onRestart;
  final VoidCallback onNextLevel;
  final VoidCallback? onSaveProgress;

  const WinModal({
    super.key,
    required this.stars,
    required this.praise,
    required this.coinsEarned,
    required this.winCoinsDoubled,
    required this.isTutorial,
    required this.isReplayRun,
    required this.nextLevelNumber,
    required this.onDoubleCoins,
    required this.onRestart,
    required this.onNextLevel,
    this.onSaveProgress,
  });

  @override
  State<WinModal> createState() => _WinModalState();
}

class _WinModalState extends State<WinModal> with TickerProviderStateMixin {
  late final List<AnimationController> _starCtrl;
  late final List<Animation<double>> _starScale;
  // Tracks which ad slot is currently loading
  _AdLoading _adLoading = _AdLoading.none;
  bool _doubled = false;

  @override
  void initState() {
    super.initState();
    _doubled = widget.winCoinsDoubled;
    _starCtrl = List.generate(
      3,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 550)),
    );
    _starScale = _starCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.elasticOut))
        .toList();

    for (int i = 0; i < widget.stars; i++) {
      Future.delayed(Duration(milliseconds: 180 + i * 240), () {
        if (mounted) _starCtrl[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _starCtrl) c.dispose();
    super.dispose();
  }

  Future<void> _watchDoubleCoinsAd() async {
    if (_adLoading != _AdLoading.none) return;
    setState(() => _adLoading = _AdLoading.doubleCoins);
    await widget.onDoubleCoins();
    if (mounted) setState(() {
      _adLoading = _AdLoading.none;
      _doubled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Replay run (after 3-star restart) → no double-coins ad shown
    final showDoubleAd =
        !widget.isTutorial && !widget.isReplayRun && widget.coinsEarned > 0 && !_doubled;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF112660), Color(0xFF0A1A3E)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated stars ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < widget.stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ScaleTransition(
                    scale: filled
                        ? _starScale[i]
                        : const AlwaysStoppedAnimation(1.0),
                    child: Icon(
                      Icons.star_rounded,
                      size: 52,
                      color: filled
                          ? const Color(0xFFF4B400)
                          : Colors.white.withValues(alpha: 0.12),
                      shadows: filled
                          ? [
                              Shadow(
                                color: const Color(0xFFF4B400)
                                    .withValues(alpha: 0.7),
                                blurRadius: 12,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // ── Praise ──
            Text(
              widget.praise,
              style: AppFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4ADE80),
              ),
            ),

            // ── Coins earned ──
            if (widget.coinsEarned > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _doubled
                        ? '+${widget.coinsEarned * 2}'
                        : '+${widget.coinsEarned}',
                    style: AppFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CoinIcon(size: 18),
                ],
              ),
            ],

            // ── Ad offers section ──
            if (showDoubleAd) ...[
              const SizedBox(height: 14),
              _adOfferTile(
                loading: _adLoading == _AdLoading.doubleCoins,
                iconBg: AppColors.purpleAccent.withValues(alpha: 0.18),
                iconBorder: AppColors.purpleAccent.withValues(alpha: 0.35),
                icon: Icons.videocam,
                iconColor: const Color(0xFFC084FC),
                title: 'Dyfisho monedhat',
                subtitle: '+${widget.coinsEarned * 2} monedha falas',
                badgeLabel: '×2',
                onTap: _watchDoubleCoinsAd,
              ),
            ],

            // ── Action buttons ──
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _modalButton(
                    label: 'Luaj përsëri',
                    icon: Icons.refresh,
                    onTap: widget.onRestart,
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _modalButton(
                    label: widget.isTutorial
                        ? 'Fillo Lojën'
                        : 'Nivel ${widget.nextLevelNumber}',
                    icon: Icons.arrow_forward_ios,
                    onTap: widget.onNextLevel,
                    isPrimary: true,
                  ),
                ),
              ],
            ),

            // ── Save progress (guest prompt) ──
            if (widget.onSaveProgress != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: widget.onSaveProgress,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.35),
                    ),
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
                        'Ruaj progresin · +100 monedha',
                        style: AppFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF93C5FD),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _adOfferTile({
    required bool loading,
    required Color iconBg,
    required Color iconBorder,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeLabel,
    Color badgeColor = const Color(0xFFF4B400),
    Color badgeTextColor = const Color(0xFF7A3F00),
    required Future<void> Function() onTap,
  }) {
    return GestureDetector(
      onTap: (_adLoading != _AdLoading.none) ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconBorder),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppFonts.nunito(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      style: AppFonts.quicksand(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
            ShikoButton(
              size: ShikoSize.medium,
              loading: loading,
              badge: badgeLabel,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared modal button helper ────────────────────────
Widget _modalButton({
  required String label,
  required IconData icon,
  required VoidCallback onTap,
  required bool isPrimary,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: isPrimary
          ? BoxDecoration(
              color: AppColors.purpleAccent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purpleAccent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}
