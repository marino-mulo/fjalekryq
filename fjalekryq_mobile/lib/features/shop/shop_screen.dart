import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/audio_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/shiko_button.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_top_bar.dart';
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

  /// If set, opens a confirmation modal for this offer after the first frame.
  /// Used by the daily-offer banner on the home screen.
  final DailyOffer? pendingOffer;

  const ShopScreen({super.key, this.specialOffer = false, this.pendingOffer});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  bool _loadingAd = false;
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
      if (widget.pendingOffer != null) {
        _showOfferConfirm(widget.pendingOffer!);
      }
    });
  }

  Future<void> _showOfferConfirm(DailyOffer offer) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => _OfferConfirmDialog(
        offer: offer,
        onConfirm: () {
          Navigator.of(ctx).pop();
          _completeOfferPurchase(offer);
        },
      ),
    );
  }

  void _completeOfferPurchase(DailyOffer offer) {
    HapticFeedback.mediumImpact();
    final coinService = context.read<CoinService>();
    final audio = context.read<AudioService>();
    audio.play(Sfx.coin);
    coinService.add(offer.coins);
    // TODO: wire real IAP purchase flow for `offer.id`.
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
    );

    if (mounted) {
      setState(() => _loadingAd = false);
      if (success) {
        final remaining = await adService.remainingToday(AdType.bonusCoins);
        if (mounted) setState(() => _adWatchesRemaining = remaining);
      }
    }
  }

  void _onPurchase(_PkgData pkg) {
    HapticFeedback.lightImpact();
    context.read<AudioService>().play(Sfx.button);
    if (pkg.isStarterPack) {
      context.read<SharedPreferences>().setBool(_starterPackShownKey, true);
      if (mounted) setState(() => _starterPackAvailable = false);
    }
    // TODO: implement real IAP
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<CoinService>().coins;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(coins),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          // ── Out of coins ──────────────────────────────
                          if (coins == 0) _buildOutOfCoinsCard(),

                          // ── Starter Pack (first time only) ────────────
                          if (_starterPackAvailable) _buildStarterPackCard(),

                          // ── Special Offer (2+ fails) ──────────────────
                          if (widget.specialOffer) _buildSpecialOfferSection(),

                          // ── Standard packages header ──────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
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

                          // ── 2-column package grid (Expanded = fills remaining height) ──
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  Expanded(
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
                                  Expanded(
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
                          ),

                          // ── Free coins (watch ad) ─────────────────────
                          _buildAdSection(),

                          // ── Restore purchases ─────────────────────────
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
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
              ],
            ),
          ),
        ],
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
                    Text(
                      '+ $hints ⭐',
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
      child: Text(
        '+${data.hints} ⭐ hint',
        style: AppFonts.nunito(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.yellowAccent,
        ),
      ),
    );
  }
}

// ─── Offer confirm dialog ────────────────────────────────────────────────────

class _OfferConfirmDialog extends StatelessWidget {
  final DailyOffer offer;
  final VoidCallback onConfirm;

  const _OfferConfirmDialog({required this.offer, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        decoration: BoxDecoration(
          gradient: modalGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.purpleAccent.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleAccent.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 38)),
            const SizedBox(height: 8),
            Text(
              'Oferta Ditore',
              style: AppFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Konfirmo blerjen për ${offer.price}',
              textAlign: TextAlign.center,
              style: AppFonts.quicksand(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CoinIcon(size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${offer.coins}',
                    style: AppFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.lightbulb_rounded,
                      size: 20, color: AppColors.yellowAccent),
                  const SizedBox(width: 6),
                  Text(
                    '${offer.hints}',
                    style: AppFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.yellowAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'ANULO',
                    variant: AppButtonVariant.secondary,
                    expanded: true,
                    height: 46,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'BLEJ ${offer.price}',
                    icon: Icons.shopping_cart_rounded,
                    expanded: true,
                    height: 46,
                    onTap: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
