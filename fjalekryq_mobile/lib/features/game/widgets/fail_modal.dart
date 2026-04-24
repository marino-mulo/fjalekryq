import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/coin_service.dart';
import '../../../shared/constants/theme.dart';

/// Inline "puzzle failed" panel shown below the game board.
///
/// Layout:
///   • red "Lëvizjet Mbaruan!" title with a warning icon (no container)
///   • one revive banner styled like the win-screen "x2 monedha" banner —
///     coins variant when the player can afford, ad variant otherwise
///   • secondary glass "Fillo nga Fillimi" button with a restart icon
class InlineFailPanel extends StatefulWidget {
  final AdService adService;
  final CoinService coinService;
  final Future<void> Function() onWatchAd;
  final VoidCallback onBuyMoves;
  final VoidCallback onRestart;

  const InlineFailPanel({
    super.key,
    required this.adService,
    required this.coinService,
    required this.onWatchAd,
    required this.onBuyMoves,
    required this.onRestart,
  });

  @override
  State<InlineFailPanel> createState() => _InlineFailPanelState();
}

class _InlineFailPanelState extends State<InlineFailPanel> {
  static const int _coinCost = 50;
  static const Color _failRed = Color(0xFFEF4444);

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

  @override
  Widget build(BuildContext context) {
    final canAffordCoins = widget.coinService.canAfford(_coinCost);
    final canWatchAd     = _adRemaining > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Red title + warning icon. No background, no border — just
          // the text, matching the "quiet message in the middle" brief.
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _failRed, size: 22),
              const SizedBox(width: 8),
              Text(
                'Lëvizjet Mbaruan!',
                style: AppFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _failRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Exactly one revive banner — coins preferred, ad as fallback.
          if (canAffordCoins)
            _coinReviveBanner()
          else if (canWatchAd)
            _adReviveBanner(),

          if (canAffordCoins || canWatchAd) const SizedBox(height: 12),

          _restartButton(),
        ],
      ),
    );
  }

  // ── Coin revive banner — same purple shape as the win-screen x2 banner ──

  Widget _coinReviveBanner() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onBuyMoves();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.purpleAccent.withValues(alpha: 0.38),
          ),
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
            const Icon(Icons.videocam_rounded,
                color: Color(0xFFC084FC), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vazhdo lojën · +5 lëvizje',
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
                  color: AppColors.purpleAccent.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '$_coinCost',
                    style: AppFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFE9D5FF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ad revive banner — same shape, purple variant ────────────────────────

  Widget _adReviveBanner() {
    return GestureDetector(
      onTap: _loadingAd
          ? null
          : () async {
              HapticFeedback.mediumImpact();
              setState(() => _loadingAd = true);
              await widget.onWatchAd();
              if (mounted) setState(() => _loadingAd = false);
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.purpleAccent.withValues(alpha: 0.38),
          ),
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
            const Icon(Icons.videocam_rounded,
                color: Color(0xFFC084FC), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vazhdo lojën · +5 lëvizje',
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
                  color: AppColors.purpleAccent.withValues(alpha: 0.55),
                ),
              ),
              child: _loadingAd
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE9D5FF),
                      ),
                    )
                  : Text(
                      'Shiko · +5',
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

  // ── Secondary: restart (glass style, with refresh icon) ──────────────────

  Widget _restartButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onRestart();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded,
                color: Colors.white.withValues(alpha: 0.85), size: 18),
            const SizedBox(width: 8),
            Text(
              'Fillo nga Fillimi',
              style: AppFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
