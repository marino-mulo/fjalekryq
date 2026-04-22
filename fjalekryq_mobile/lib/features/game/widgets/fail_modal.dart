import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/coin_service.dart';
import '../../../shared/constants/theme.dart';
import '../../../shared/widgets/coin_badge.dart';
import '../../../shared/widgets/shiko_button.dart';

/// Inline "puzzle failed" panel shown below the game board.
///
/// Replaces the previous full-screen modal so the puzzle stays visible and
/// the player never leaves the game page on failure. Offers two revive
/// paths (ad or coins) plus a restart action.
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
    final canAfford30 = widget.coinService.canAfford(30);
    final canWatchAd = _adRemaining > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE53935).withValues(alpha: 0.42),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFCA5A5), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lëvizjet Mbaruan!',
                    style: AppFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFCA5A5),
                    ),
                  ),
                ),
                Text(
                  'Vazhdo ose fillo sërish',
                  style: AppFonts.quicksand(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (canWatchAd) ...[
              _buildWatchAdTile(),
              const SizedBox(height: 8),
            ],
            _buildBuyMovesTile(canAfford30),
            const SizedBox(height: 10),
            _buildRestartButton(),
          ],
        ),
      ),
    );
  }

  // ── Watch ad (primary continue) ──────────────────────────────────────────

  Widget _buildWatchAdTile() {
    return GestureDetector(
      onTap: _loadingAd
          ? null
          : () async {
              setState(() => _loadingAd = true);
              await widget.onWatchAd();
              if (mounted) setState(() => _loadingAd = false);
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.purpleAccent.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam_rounded,
                color: Color(0xFFE040FB), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Vazhdo · Shiko Reklamë +5 Lëvizje',
                style: AppFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            ShikoButton(
              size: ShikoSize.small,
              loading: _loadingAd,
              badge: '+5',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Buy moves (coins continue) ───────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFDD835), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bli 5 Lëvizje',
                  style: AppFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '30',
                      style: AppFonts.nunito(
                        fontSize: 12,
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

  // ── Restart ──────────────────────────────────────────────────────────────

  Widget _buildRestartButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onRestart();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded,
                color: Color(0xFFC62828), size: 18),
            const SizedBox(width: 8),
            Text(
              'Fillo nga Fillimi',
              style: AppFonts.nunito(
                fontSize: 14,
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
