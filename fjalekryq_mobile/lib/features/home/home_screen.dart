import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/daily_puzzle_service.dart';
import '../../shared/constants/theme.dart';
import '../level_map/level_map_screen.dart';
import '../daily/daily_game_screen.dart';
import '../settings/settings_sheet.dart';
import '../shop/daily_reward_sheet.dart';
import '../shop/shop_screen.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_button.dart';
import 'daily_offer.dart';
import 'daily_offer_banner.dart';
import 'leaderboard_full_screen.dart';

const _levelKey = 'fjalekryq_level';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _level = 1;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late AnimationController _pulseController;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<SharedPreferences>();
    _level = prefs.getInt(_levelKey) ?? 1;
    if (_level < 1) _level = 1;

    // Entrance animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));

    // Logo float animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _logoScale = Tween(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Pulse for daily reward
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Defer ALL heavy work well after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _fadeController.forward();
    });
    // Delay animations and music further to let the UI settle
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _logoController.repeat(reverse: true);
      _pulseController.repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      context.read<AudioService>().startMusic();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _openLevelMap() {
    HapticFeedback.lightImpact();
    context.read<AudioService>().play(Sfx.button);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const LevelMapScreen(),
    ));
  }

  void _openDailyPuzzle() {
    HapticFeedback.lightImpact();
    context.read<AudioService>().play(Sfx.button);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const DailyGameScreen(),
    ));
  }

  void _openSettings() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsSheet()),
    );
  }

  void _openDailyReward() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const DailyRewardSheet(),
    );
  }

  void _openLeaderboard() {
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const LeaderboardFullScreen(),
      fullscreenDialog: true,
    ));
  }

  void _openShop() {
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const ShopScreen(),
    ));
  }

  void _openDailyOffer() {
    final offer = offerForPrefs(context.read<SharedPreferences>());
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ShopScreen(pendingOffer: offer),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final coinService = context.watch<CoinService>();
    final dailyAvailable = coinService.peekDaily() != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
          // Header pinned at top, edge-to-edge (matching web .menu-header)
          _buildHeader(dailyAvailable, MediaQuery.of(context).padding.top),

          // Top-right floating daily offer banner (always shown; tier
          // progression is tracked in SharedPreferences).
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 12,
            child: DailyOfferBanner(
              offer: offerForPrefs(context.read<SharedPreferences>()),
              onTap: _openDailyOffer,
            ),
          ),

          // Main content below header
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      // Space for the header
                      const SizedBox(height: 56),

                      const Spacer(flex: 5),

                      // Logo area with float animation
                      AnimatedBuilder(
                        animation: _logoScale,
                        builder: (context, child) => Transform.scale(
                          scale: _logoScale.value,
                          child: Transform.translate(
                            offset: Offset(0, -7 * (_logoScale.value - 1) / 0.03),
                            child: child,
                          ),
                        ),
                        child: _buildLogoSection(),
                      ),

                      const Spacer(flex: 3),

                      // CTA buttons side-by-side (matching web: flex-direction: row)
                      _buildActionButtons(),

                      const Spacer(flex: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  // Web: .menu-header — full-width glass bar pinned at top
  Widget _buildHeader(bool dailyAvailable, double statusBarHeight) {
    final coins = context.watch<CoinService>().coins;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: statusBarHeight + 10,
          bottom: 10,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            _DailyRewardButton(
              onTap: _openDailyReward,
              available: dailyAvailable,
              pulseController: _pulseController,
            ),
            const SizedBox(width: 8),
            _HeaderButton(
              icon: Icons.leaderboard_rounded,
              onTap: _openLeaderboard,
            ),
            const Spacer(),
            _HeaderButton(
              icon: Icons.settings,
              onTap: _openSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 200,
          height: 200,
        ),
        const SizedBox(height: 14),
        // Game tag: "LOJA E FJALEVE SHQIP" with dots (matching web .game-tag)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFFBA27).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LOJA E FJALËVE SHQIP',
              style: AppFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: const Color(0xFFFFBA27).withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFFBA27).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Web: .menu-actions { flex-direction: row; gap: 10px; }
  Widget _buildActionButtons() {
    final streak = context.watch<DailyPuzzleService>().currentStreak;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Row(
          children: [
            // Play button - primary CTA
            Expanded(
              child: AppButton(
                label: 'LUAJ',
                icon: Icons.play_arrow_rounded,
                onTap: _openLevelMap,
                expanded: true,
                height: 56,
              ),
            ),
            const SizedBox(width: 10),
            // Daily puzzle button - secondary glass with streak badge
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppButton(
                    label: 'DITOR',
                    icon: Icons.today_rounded,
                    onTap: _openDailyPuzzle,
                    variant: AppButtonVariant.secondary,
                    expanded: true,
                    height: 56,
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: _StreakBadge(streak: streak),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Daily reward button with gold tint + pulsing when available (matching web .daily-reward-btn).
class _DailyRewardButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool available;
  final AnimationController pulseController;

  const _DailyRewardButton({
    required this.onTap,
    required this.available,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: available
                      ? AppColors.gold.withValues(alpha: 0.2)
                      : const Color(0xFFF4B400).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: available
                        ? AppColors.gold.withValues(alpha: 0.6)
                        : const Color(0xFFF4B400).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: available
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(
                              alpha: 0.15 + pulseController.value * 0.25,
                            ),
                            blurRadius: 8 + pulseController.value * 8,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: available
                      ? AppColors.gold
                      : const Color(0xFFFFD86B),
                  size: 20,
                ),
              );
            },
          ),
          if (available)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0C1F4A), width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Flame streak badge shown on the Ditor button.
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFF6B35)
            : const Color(0xFF2A3B6B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0C1F4A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
            size: 11,
          ),
          const SizedBox(width: 2),
          Text(
            '$streak',
            style: TextStyle(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable header icon button (matching web .header-icon-btn).
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
      ),
    );
  }
}
