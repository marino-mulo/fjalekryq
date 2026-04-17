import 'package:flutter/material.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/coin_service.dart';
import '../../../shared/constants/theme.dart';
import '../../../shared/widgets/coin_badge.dart';
import '../../../shared/widgets/shiko_button.dart';

class FailModal extends StatefulWidget {
  final AdService adService;
  final CoinService coinService;
  final Future<void> Function() onWatchAd;
  final VoidCallback onBuyMoves;
  final VoidCallback onRestart;

  const FailModal({
    super.key,
    required this.adService,
    required this.coinService,
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

  @override
  Widget build(BuildContext context) {
    final canAfford30 = widget.coinService.canAfford(30);
    final canWatchAd = _adRemaining > 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1020), Color(0xFF0A1A3E)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFFCA5A5).withValues(alpha: 0.22),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
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
            // ── Empty stars ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.star_rounded,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Title ──
            Text(
              'Dështove!',
              style: AppFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFCA5A5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lëvizjet mbaruan. Vazhdo ose fillo sërish.',
              textAlign: TextAlign.center,
              style: AppFonts.quicksand(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 20),

            // ── Watch Ad for +5 moves (hidden when daily limit reached) ──
            if (canWatchAd) ...[
              _failOption(
                icon: Icons.videocam_rounded,
                iconColor: const Color(0xFFC084FC),
                iconBg: AppColors.purpleAccent.withValues(alpha: 0.18),
                iconBorder: AppColors.purpleAccent.withValues(alpha: 0.35),
                title: 'Shiko reklamë · +5 lëvizje',
                subtitle: 'Shiko një reklamë të shkurtër',
                trailing: ShikoButton(
                  size: ShikoSize.medium,
                  loading: _loadingAd,
                  onTap: null,
                ),
                onTap: _loadingAd
                    ? null
                    : () async {
                        setState(() => _loadingAd = true);
                        await widget.onWatchAd();
                      },
              ),
              const SizedBox(height: 10),
            ],

            // ── Buy 5 moves with 30 coins ──
            _failOption(
              icon: Icons.monetization_on_rounded,
              iconColor: AppColors.gold,
              iconBg: AppColors.gold.withValues(alpha: 0.14),
              iconBorder: AppColors.gold.withValues(alpha: 0.3),
              title: 'Bli 5 lëvizje · 30 monedha',
              subtitle: canAfford30
                  ? 'Bilanci: ${widget.coinService.coins} monedha'
                  : 'Nuk keni monedha të mjaftueshme',
              trailing: Opacity(
                opacity: canAfford30 ? 1.0 : 0.4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
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
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              onTap: canAfford30 ? widget.onBuyMoves : null,
            ),

            const SizedBox(height: 16),

            // ── Restart ──
            GestureDetector(
              onTap: widget.onRestart,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Fillo nga fillimi',
                      style: AppFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color iconBorder,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconBorder),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      subtitle,
                      style: AppFonts.quicksand(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
