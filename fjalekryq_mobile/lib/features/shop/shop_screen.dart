import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/audio_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/shiko_button.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/offline_view.dart';
import '../home/daily_offer.dart';

const _starterPackShownKey = 'fjalekryq_starter_pack_shown';

// ─── Package data model ────────────────────────────────────────────────────

enum _PackageVariant { normal, popular, bestDeal }

class _PkgData {
  final String price;
  final int coins;
  final int hints;
  final String? badge;
  final _PackageVariant variant;
  final bool isStarterPack;
  final bool isSpecial;

  const _PkgData({
    required this.price,
    required this.coins,
    this.hints = 0,
    this.badge,
    this.variant = _PackageVariant.normal,
    this.isStarterPack = false,
    this.isSpecial = false,
  });
}

// ─── Screen ────────────────────────────────────────────────────────────────

/// Full-page coin shop.
///
/// Pass [specialOffer] = true when the user has failed the same level 2+ times
/// to reveal the "Special Offer / SUPER POWER" section with boosted packages.
class ShopScreen extends StatefulWidget {
  final bool specialOffer;

  /// Kept for backward compatibility; the shop now always shows the current
  /// tier's [offerForPrefs] regardless of how it was opened.
  final DailyOffer? pendingOffer;

  const ShopScreen({super.key, this.specialOffer = false, this.pendingOffer});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  bool _loadingAd = false;
  bool _loadingRemoveAds = false;
  int _adWatchesRemaining = 5;
  bool _starterPackAvailable = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    // Badge pulse: subtle scale oscillation for "MOST POPULAR"
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Glow pulse: border/shadow brightness for "BEST DEAL"
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Entrance fade + slide
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterCtrl.forward();
      _loadData();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = context.read<SharedPreferences>();
    final adService = context.read<AdService>();
    final shown = prefs.getBool(_starterPackShownKey) ?? false;
    final remaining = await adService.remainingToday(AdType.bonusCoins);
    if (mounted) {
      setState(() {
        _starterPackAvailable = !shown;
        _adWatchesRemaining = remaining;
      });
    }
  }

  Future<void> _watchAdForCoins() async {
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
      onOffline: () {
        if (mounted) showOfflineSnack(context);
      },
    );

    if (mounted) {
      setState(() => _loadingAd = false);
      if (success) {
        final remaining = await adService.remainingToday(AdType.bonusCoins);
        if (mounted) setState(() => _adWatchesRemaining = remaining);
      }
    }
  }

  Future<void> _onPurchase(_PkgData pkg) async {
    HapticFeedback.lightImpact();
    context.read<AudioService>().play(Sfx.button);
    final prefs = context.read<SharedPreferences>();
    if (pkg.isStarterPack) {
      prefs.setBool(_starterPackShownKey, true);
      if (mounted) setState(() => _starterPackAvailable = false);
    }
    // When the current daily-offer tier is purchased, advance to the next
    // tier so the user sees the $1.99 → $2.99 offer on subsequent visits.
    if (pkg.isSpecial) {
      await advanceOfferTier(prefs);
      if (mounted) setState(() {});
    }
    // TODO: implement real IAP
  }

  Future<void> _purchaseRemoveAds() async {
    if (_loadingRemoveAds) return;
    HapticFeedback.lightImpact();
    context.read<AudioService>().play(Sfx.button);
    setState(() => _loadingRemoveAds = true);
    final success = await context.read<AdService>().purchaseRemoveAds();
    if (mounted) {
      setState(() => _loadingRemoveAds = false);
      if (success) HapticFeedback.mediumImpact();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<CoinService>().coins;
    final adsRemoved = context.watch<AdService>().removeAds;
    // Shop always surfaces the current tier of the daily offer, regardless
    // of where it was opened from (home banner, game screen, daily screen).
    final todaysOffer =
        widget.pendingOffer ?? offerForPrefs(context.read<SharedPreferences>());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(coins),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          // ── Offline banner (reactive) ─────────────────
                          const OfflineBanner(),

                          // ── Daily offer (always shown) ────────────────
                          _buildDailyOfferCard(todaysOffer),

                          // ── Out of coins ──────────────────────────────
                          if (coins == 0) _buildOutOfCoinsCard(),

                          // ── Starter Pack (first time only) ────────────
                          if (_starterPackAvailable) _buildStarterPackCard(),

                          // ── Special Offer (2+ fails) ──────────────────
                          if (widget.specialOffer) _buildSpecialOfferSection(),

                          // ── Standard packages header ──────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_cart_rounded,
                                  color: Color(0xFFF4B400),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Bli Monedha',
                                  style: AppFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── 2-column package grid (fixed heights, no overflow) ──
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 110,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _PackageCard(
                                          data: const _PkgData(price: '\$0.99', coins: 100),
                                          onTap: _onPurchase,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _PackageCard(
                                          data: const _PkgData(
                                            price: '\$1.99',
                                            coins: 250,
                                            hints: 1,
                                            badge: '🔥 POPULAR',
                                            variant: _PackageVariant.popular,
                                          ),
                                          onTap: _onPurchase,
                                          pulseCtrl: _pulseCtrl,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 110,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _PackageCard(
                                          data: const _PkgData(price: '\$2.99', coins: 600),
                                          onTap: _onPurchase,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _PackageCard(
                                          data: const _PkgData(
                                            price: '\$4.99',
                                            coins: 1000,
                                            hints: 3,
                                            badge: '💎 BEST DEAL',
                                            variant: _PackageVariant.bestDeal,
                                          ),
                                          onTap: _onPurchase,
                                          glowCtrl: _glowCtrl,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Free coins (watch ad) ─────────────────────
                          _buildAdSection(),

                          // ── Remove Ads IAP ────────────────────────────
                          _buildRemoveAdsCard(adsRemoved),

                          // ── Restore purchases ─────────────────────────
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  // TODO: restore purchases
                                },
                                child: Text(
                                  'Rivendos Blerjet',
                                  style: AppFonts.quicksand(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(int coins) {
    return AppTopBar(
      title: 'BLI',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 14),
            const SizedBox(width: 6),
            Text(
              '$coins',
              style: AppFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Out of coins banner ───────────────────────────────────────────────────

  Widget _buildOutOfCoinsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF4040).withValues(alpha: 0.18),
            const Color(0xFF7B0000).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFCA5A5).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4040).withValues(alpha: 0.15),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('😢', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Out of coins!',
                  style: AppFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFCA5A5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Merr monedha për të vazhduar lojën',
                  style: AppFonts.quicksand(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily offer (surfaced from home banner) ───────────────────────────────

  Widget _buildDailyOfferCard(DailyOffer offer) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, _) {
        final glow = 0.18 + _glowCtrl.value * 0.25;
        final borderAlpha = 0.45 + _glowCtrl.value * 0.3;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purpleAccent.withValues(alpha: 0.22),
                AppColors.purpleDark.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.purpleAccent.withValues(alpha: borderAlpha),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleAccent.withValues(alpha: glow),
                blurRadius: 16 + _glowCtrl.value * 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.purpleAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.purpleAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '🎁 OFERTË DITORE',
                      style: AppFonts.nunito(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE9D5FF),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Vetëm sot!',
                    style: AppFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SpecialRow(
                price: offer.price,
                coins: offer.coins,
                hints: offer.hints,
                onTap: () => _onPurchase(_PkgData(
                  price: offer.price,
                  coins: offer.coins,
                  hints: offer.hints,
                  isSpecial: true,
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Starter Pack (first-time only) ────────────────────────────────────────

  Widget _buildStarterPackCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purpleAccent.withValues(alpha: 0.22),
            const Color(0xFF0F0B2A),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purpleAccent.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleAccent.withValues(alpha: 0.2),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.purpleAccent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.purpleAccent.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              '✨ VETËM NJË HERË',
              style: AppFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD8B4FE),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Starter Pack',
            style: AppFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Ofertë speciale vetëm për herën e parë!',
            style: AppFonts.quicksand(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          _SpecialRow(
            price: '\$0.99',
            coins: 200,
            hints: 1,
            onTap: () => _onPurchase(const _PkgData(
              price: '\$0.99',
              coins: 200,
              hints: 1,
              isStarterPack: true,
            )),
          ),
        ],
      ),
    );
  }

  // ── Special Offer (after 2+ fails) ────────────────────────────────────────

  Widget _buildSpecialOfferSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.18),
            const Color(0xFF1A0A00),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag('⚡ SUPER POWER', AppColors.gold,
                  AppColors.gold.withValues(alpha: 0.22)),
              _tag('E KUFIZUAR', const Color(0xFFFCA5A5),
                  Colors.red.withValues(alpha: 0.18)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Special Offer',
            style: AppFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Kjo do të të çojë në nivelin tjetër! 👉',
            style: AppFonts.quicksand(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          _SpecialRow(
            price: '\$0.99',
            coins: 200,
            hints: 1,
            isLimited: true,
            onTap: () => _onPurchase(const _PkgData(
              price: '\$0.99',
              coins: 200,
              hints: 1,
              isSpecial: true,
            )),
          ),
          const SizedBox(height: 10),
          _SpecialRow(
            price: '\$1.99',
            coins: 350,
            hints: 2,
            isLimited: true,
            onTap: () => _onPurchase(const _PkgData(
              price: '\$1.99',
              coins: 350,
              hints: 2,
              isSpecial: true,
            )),
          ),
        ],
      ),
    );
  }

  // ── Remove Ads IAP ────────────────────────────────────────────────────────

  Widget _buildRemoveAdsCard(bool alreadyPurchased) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1).withValues(alpha: 0.18),
              const Color(0xFF8B5CF6).withValues(alpha: 0.22),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF818CF8).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  alreadyPurchased ? Icons.block : Icons.block_outlined,
                  color: const Color(0xFFA5B4FC),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hiq Reklamat',
                      style: AppFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      alreadyPurchased
                          ? '✓ Blerë — Shijoni lojën pa reklama!'
                          : 'Hiqni banerat dhe reklamat ndërmjet niveleve',
                      style: AppFonts.quicksand(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (!alreadyPurchased) ...[
                const SizedBox(width: 10),
                _loadingRemoveAds
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFA5B4FC),
                        ),
                      )
                    : GestureDetector(
                        onTap: _purchaseRemoveAds,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  const Color(0xFF818CF8).withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            AppConfig.removeAdsPriceLabel,
                            style: AppFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFE0E7FF),
                            ),
                          ),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Free coins (watch ad) ─────────────────────────────────────────────────

  Widget _buildAdSection() {
    final available = _adWatchesRemaining > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                color: Color(0xFFE2C9FF),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Monedha Falas',
                style: AppFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShikoButton(
            size: ShikoSize.large,
            loading: _loadingAd,
            onTap: available ? _watchAdForCoins : null,
            label: available
                ? 'Shiko reklamë — 30 monedha ($_adWatchesRemaining herë)'
                : 'Keni arritur limitin e sotëm',
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _tag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: AppFonts.nunito(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Special offer row widget ─────────────────────────────────────────────

class _SpecialRow extends StatelessWidget {
  final String price;
  final int coins;
  final int hints;
  final bool isLimited;
  final VoidCallback onTap;

  const _SpecialRow({
    required this.price,
    required this.coins,
    required this.hints,
    this.isLimited = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            // Price tag
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Text(
                price,
                style: AppFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Coins + hints
            Expanded(
              child: Row(
                children: [
                  const CoinIcon(size: 15),
                  const SizedBox(width: 5),
                  Text(
                    '$coins',
                    style: AppFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (hints > 0) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.lightbulb,
                      size: 15,
                      color: AppColors.yellowAccent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '+$hints hint',
                      style: AppFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.yellowAccent,
                      ),
                    ),
                  ],
                  if (isLimited) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LIMITED',
                        style: AppFonts.nunito(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFCA5A5),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── Package card (animated for popular / best-deal) ─────────────────────

class _PackageCard extends StatelessWidget {
  final _PkgData data;
  final void Function(_PkgData) onTap;
  /// Passed for "MOST POPULAR" — drives scale pulse on the card.
  final AnimationController? pulseCtrl;
  /// Passed for "BEST DEAL" — drives glow/border brightness.
  final AnimationController? glowCtrl;

  const _PackageCard({
    required this.data,
    required this.onTap,
    this.pulseCtrl,
    this.glowCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = data.variant == _PackageVariant.popular;
    final isBestDeal = data.variant == _PackageVariant.bestDeal;

    final Color accentColor = isBestDeal
        ? AppColors.gold
        : isPopular
            ? AppColors.purpleAccent
            : Colors.white.withValues(alpha: 0.12);

    // The animated container (glow + border pulse)
    final ctrl = glowCtrl ?? pulseCtrl;
    Widget card = GestureDetector(
      onTap: () => onTap(data),
      child: AnimatedBuilder(
        animation: ctrl ?? kAlwaysCompleteAnimation,
        builder: (_, child) {
          final t = ctrl?.value ?? 0.0;
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: isPopular
                  ? AppColors.purpleAccent.withValues(alpha: 0.1)
                  : isBestDeal
                      ? AppColors.gold.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (isPopular || isBestDeal)
                    ? accentColor.withValues(alpha: 0.35 + t * 0.2)
                    : accentColor,
                width: (isPopular || isBestDeal) ? 1.8 : 1.5,
              ),
              boxShadow: (isPopular || isBestDeal)
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(
                            alpha: 0.12 + t * 0.18),
                        blurRadius: 10 + t * 14,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            // ── Left: coins ──────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CoinIcon(size: isBestDeal ? 24 : 20),
                  const SizedBox(height: 2),
                  Text(
                    '${data.coins}',
                    style: AppFonts.nunito(
                      fontSize: isBestDeal ? 16 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'monedha',
                    style: AppFonts.quicksand(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  if (data.hints > 0) ...[
                    const SizedBox(height: 3),
                    _buildHintBadge(),
                  ],
                ],
              ),
            ),
            // ── Right: badge + price ─────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (data.badge != null) ...[
                    _buildBadge(isPopular, isBestDeal),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    data.price,
                    style: AppFonts.nunito(
                      fontSize: isBestDeal ? 15 : 13,
                      fontWeight: FontWeight.w900,
                      color: isBestDeal
                          ? AppColors.gold
                          : isPopular
                              ? const Color(0xFFD8B4FE)
                              : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap popular card in a subtle scale pulse
    if (isPopular && pulseCtrl != null) {
      card = AnimatedBuilder(
        animation: pulseCtrl!,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + pulseCtrl!.value * 0.015,
          child: child,
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildBadge(bool isPopular, bool isBestDeal) {
    final Color color =
        isBestDeal ? AppColors.gold : AppColors.purpleAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        data.badge!,
        style: AppFonts.nunito(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHintBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.yellowAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppColors.yellowAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb,
            size: 10,
            color: AppColors.yellowAccent,
          ),
          const SizedBox(width: 3),
          Text(
            '+${data.hints} hint',
            style: AppFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.yellowAccent,
            ),
          ),
        ],
      ),
    );
  }
}

