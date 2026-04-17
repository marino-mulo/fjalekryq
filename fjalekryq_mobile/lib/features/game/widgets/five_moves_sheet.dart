import 'package:flutter/material.dart';
import '../../../core/services/ad_service.dart';
import '../../../shared/constants/theme.dart';
import '../../../shared/widgets/coin_badge.dart';
import '../../../shared/widgets/shiko_button.dart';

class FiveMovesSheet extends StatefulWidget {
  final int coins;
  final AdService adService;
  final Future<void> Function() onWatchAd;
  final VoidCallback onBuyMoves;
  final VoidCallback onDismiss;

  const FiveMovesSheet({
    super.key,
    required this.coins,
    required this.adService,
    required this.onWatchAd,
    required this.onBuyMoves,
    required this.onDismiss,
  });

  @override
  State<FiveMovesSheet> createState() => _FiveMovesSheetState();
}

class _FiveMovesSheetState extends State<FiveMovesSheet> {
  bool _loadingAd = false;
  int _adRemaining = 5;

  @override
  void initState() {
    super.initState();
    widget.adService
        .remainingToday(AdType.continueAfterLoss)
        .then((r) { if (mounted) setState(() => _adRemaining = r); });
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = widget.coins >= 30;
    final canWatch = _adRemaining > 0;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2D5A), Color(0xFF0A1A3E)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Warning icon + title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFB923C),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vetëm 5 lëvizje të mbetura!',
                      style: AppFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFB923C),
                      ),
                    ),
                    Text(
                      'Merr 5 lëvizje shtesë tani.',
                      style: AppFonts.quicksand(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Watch ad option
          if (canWatch)
            GestureDetector(
              onTap: _loadingAd
                  ? null
                  : () async {
                      setState(() => _loadingAd = true);
                      await widget.onWatchAd();
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.purpleAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.purpleAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: Color(0xFFC084FC), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Shiko reklamë · +5 lëvizje',
                        style: AppFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    ShikoButton(size: ShikoSize.small, loading: _loadingAd, onTap: null),
                  ],
                ),
              ),
            ),

          // Buy with coins option
          GestureDetector(
            onTap: canAfford ? widget.onBuyMoves : null,
            child: Opacity(
              opacity: canAfford ? 1.0 : 0.4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const CoinIcon(size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bli 5 lëvizje · 30 monedha',
                        style: AppFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: canAfford ? AppColors.gold : Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.coins}',
                      style: AppFonts.nunito(
                        fontSize: 12,
                        color: AppColors.gold.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Dismiss
          GestureDetector(
            onTap: widget.onDismiss,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Vazhdo pa lëvizje shtesë',
                style: AppFonts.quicksand(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
