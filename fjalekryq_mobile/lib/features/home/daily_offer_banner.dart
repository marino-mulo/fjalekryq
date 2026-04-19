import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/constants/theme.dart';
import 'daily_offer.dart';

/// Small floating card that advertises the currently available tier of the
/// daily offer. The banner is always visible — it cannot be dismissed;
/// instead the tier advances after a successful purchase.
class DailyOfferBanner extends StatelessWidget {
  final DailyOffer offer;
  final VoidCallback onTap;

  const DailyOfferBanner({
    super.key,
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.purpleAccent.withValues(alpha: 0.25),
              AppColors.purpleDark.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.purpleAccent.withValues(alpha: 0.5),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleAccent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: badge + price
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.purpleAccent.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.purpleAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '🎁 OFERTË DITORE',
                    style: AppFonts.nunito(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: const Color(0xFFE9D5FF),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  offer.price,
                  style: AppFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Bottom row: coins | hints | arrow
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 14),
                const SizedBox(width: 4),
                Text(
                  '${offer.coins}',
                  style: AppFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${offer.hints} hint',
                  style: AppFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.yellowAccent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.lightbulb,
                  size: 13,
                  color: AppColors.yellowAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
