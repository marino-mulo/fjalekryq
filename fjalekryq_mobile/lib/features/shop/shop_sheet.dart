import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/audio_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/shiko_button.dart';

/// Bottom sheet for the coin shop (IAP placeholder).
class ShopSheet extends StatefulWidget {
  const ShopSheet({super.key});

  @override
  State<ShopSheet> createState() => _ShopSheetState();
}

class _ShopSheetState extends State<ShopSheet> {
  bool _loadingAd = false;
  int _adWatchesRemaining = 3;

  @override
  void initState() {
    super.initState();
    _loadAdRemaining();
  }

  void _loadAdRemaining() async {
    final adService = context.read<AdService>();
    final remaining = await adService.remainingToday(AdType.bonusCoins);
    if (mounted) setState(() => _adWatchesRemaining = remaining);
  }

  void _watchAdForCoins() async {
    if (_loadingAd || _adWatchesRemaining <= 0) return;
    final adService = context.read<AdService>();
    final coinService = context.read<CoinService>();
    final audio = context.read<AudioService>();

    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.bonusCoins,
      onReward: () async {
        coinService.add(30);
        audio.play(Sfx.coin);
        HapticFeedback.mediumImpact();
      },
    );

    if (mounted) {
      setState(() => _loadingAd = false);
      if (success) _loadAdRemaining();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            gradient: modalGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Header ---
                _buildHeader(),
                const SizedBox(height: 6),
                Text(
                  'Shto monedha n\u00eb llogarin\u00eb t\u00ebnde',
                  style: AppFonts.quicksand(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 20),

                // --- Watch Ad Section ---
                _buildAdSection(),
                const SizedBox(height: 14),

                // --- Shop Packages Grid ---
                _buildPackagesGrid(),
                const SizedBox(height: 16),

                // --- Restore purchases ---
                GestureDetector(
                  onTap: () {
                    // TODO: Implement restore purchases
                  },
                  child: Text(
                    'Rivendos Blerjet',
                    style: AppFonts.quicksand(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- Close Button ---
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Mbyll',
                      style: AppFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Header with cart icon, title, and close button
  // -------------------------------------------------------
  Widget _buildHeader() {
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart,
              color: Color(0xFFF4B400),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Bli Monedha',
              style: AppFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Watch ad for coins section
  // -------------------------------------------------------
  Widget _buildAdSection() {
    final available = _adWatchesRemaining > 0;
    return ShikoButton(
      size: ShikoSize.large,
      loading: _loadingAd,
      onTap: available ? _watchAdForCoins : null,
      label: available
          ? 'Shiko reklamë — 30 monedha ($_adWatchesRemaining herë)'
          : 'Shiko reklamë — Limiti',
    );
  }

  // -------------------------------------------------------
  // 2-column packages grid
  // -------------------------------------------------------
  Widget _buildPackagesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: const [
        _ShopPackage(
          price: '\$ 0.99',
          coins: 100,
        ),
        _ShopPackage(
          price: '\$ 1.99',
          coins: 250,
          badge: 'M\u00cb E MIR\u00cb',
          variant: _PackageVariant.popular,
        ),
        _ShopPackage(
          price: '\$ 2.99',
          coins: 500,
          bonus: 50,
        ),
        _ShopPackage(
          price: '\$ 4.99',
          coins: 1000,
          bonus: 150,
          badge: 'VLERA M\u00cb E MIR\u00cb',
          variant: _PackageVariant.bestValue,
        ),
      ],
    );
  }
}

// -------------------------------------------------------
// Package variant enum
// -------------------------------------------------------
enum _PackageVariant { normal, popular, bestValue }

// -------------------------------------------------------
// Individual shop package card
// -------------------------------------------------------
class _ShopPackage extends StatelessWidget {
  final String price;
  final int coins;
  final int? bonus;
  final String? badge;
  final _PackageVariant variant;

  const _ShopPackage({
    required this.price,
    required this.coins,
    this.bonus,
    this.badge,
    this.variant = _PackageVariant.normal,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = variant == _PackageVariant.popular;
    final isBestValue = variant == _PackageVariant.bestValue;
    final coinSize = isBestValue ? 34.0 : 26.0;

    // Determine border color and glow
    Color borderColor = Colors.white.withValues(alpha: 0.12);
    List<BoxShadow>? shadows;

    if (isPopular) {
      borderColor = AppColors.purpleAccent.withValues(alpha: 0.5);
      shadows = [
        BoxShadow(
          color: AppColors.purpleAccent.withValues(alpha: 0.25),
          blurRadius: 16,
        ),
      ];
    } else if (isBestValue) {
      borderColor = AppColors.gold.withValues(alpha: 0.5);
      shadows = [
        BoxShadow(
          color: AppColors.gold.withValues(alpha: 0.25),
          blurRadius: 16,
        ),
      ];
    }

    return GestureDetector(
      onTap: () {
        // TODO: Implement IAP purchase
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: shadows,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge (if any)
            if (badge != null) ...[
              _buildBadge(),
              const SizedBox(height: 8),
            ],

            // Price
            Text(
              price,
              style: AppFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            // Coin icon
            CoinIcon(size: coinSize),
            const SizedBox(height: 6),

            // Coin count
            Text(
              '$coins',
              style: AppFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'monedha',
              style: AppFonts.quicksand(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),

            // Bonus badge (if any)
            if (bonus != null) ...[
              const SizedBox(height: 6),
              _buildBonusBadge(),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    final isPopular = variant == _PackageVariant.popular;
    final isBestValue = variant == _PackageVariant.bestValue;

    Color bgColor;
    Color textColor;
    Border? badgeBorder;

    if (isBestValue) {
      bgColor = AppColors.gold.withValues(alpha: 0.15);
      textColor = AppColors.gold;
      badgeBorder = Border.all(
        color: AppColors.gold.withValues(alpha: 0.3),
      );
    } else if (isPopular) {
      bgColor = AppColors.purpleAccent.withValues(alpha: 0.2);
      textColor = AppColors.purpleAccent;
      badgeBorder = Border.all(
        color: AppColors.purpleAccent.withValues(alpha: 0.3),
      );
    } else {
      bgColor = Colors.white.withValues(alpha: 0.1);
      textColor = Colors.white70;
      badgeBorder = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: badgeBorder,
      ),
      child: Text(
        badge!,
        style: AppFonts.nunito(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBonusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '+$bonus BONUS',
        style: AppFonts.nunito(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.greenAccent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
