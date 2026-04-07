import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/coin_service.dart';
import '../../shared/constants/theme.dart';

/// Bottom sheet for the coin shop (IAP placeholder).
class ShopSheet extends StatelessWidget {
  const ShopSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final coinService = context.watch<CoinService>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Bli Monedha',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ke ${coinService.coins} monedha',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),

          // Packages
          _ShopPackage(price: '\$0.99', coins: 100),
          _ShopPackage(price: '\$1.99', coins: 250, badge: 'MË E MIRË'),
          _ShopPackage(price: '\$2.99', coins: 500, bonus: 50),
          _ShopPackage(price: '\$4.99', coins: 1000, bonus: 150, badge: 'VLERA MË E MIRË', isGold: true),

          const SizedBox(height: 12),

          // Restore purchases
          TextButton(
            onPressed: () {
              // TODO: Implement restore purchases
            },
            child: Text(
              'Rivendos Blerjet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ),

          // Close button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Mbyll',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ShopPackage extends StatelessWidget {
  final String price;
  final int coins;
  final int? bonus;
  final String? badge;
  final bool isGold;

  const _ShopPackage({
    required this.price,
    required this.coins,
    this.bonus,
    this.badge,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: badge != null
              ? Border.all(color: isGold ? AppColors.gold : AppColors.cellGreen, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Coin icon
            const Icon(Icons.monetization_on, color: AppColors.gold, size: 28),
            const SizedBox(width: 12),
            // Coins + bonus
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: (isGold ? AppColors.gold : AppColors.cellGreen).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: isGold ? AppColors.gold : AppColors.cellGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Text(
                        '$coins',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        ' monedha',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      if (bonus != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '+$bonus BONUS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greenAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Price button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cellGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
