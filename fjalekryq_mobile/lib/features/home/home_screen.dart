import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/daily_puzzle_service.dart';
import '../../shared/constants/theme.dart';
import '../daily/daily_game_screen.dart';
import '../settings/settings_sheet.dart';
import '../shop/daily_reward_sheet.dart';
import '../shop/shop_screen.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/puzzle_logo.dart';
import '../game/game_screen.dart';
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
  bool _inProgress = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<SharedPreferences>();
    _level = prefs.getInt(_levelKey) ?? 1;
    if (_level < 1) _level = 1;
    _inProgress = prefs.getBool('fjalekryq_in_progress_$_level') ?? false;

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

    // Pulse for daily reward
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Defer ALL heavy work well after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fadeController.forward();
    });
    // Delay animations further to let the UI settle. Background music
    // has been removed from the app — only SFX remain.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _openGame() {
    HapticFeedback.lightImpact();
    context.read<AudioService>().play(Sfx.button);
    final prefs = context.read<SharedPreferences>();
    final level = prefs.getInt(_levelKey) ?? 1;
    prefs.setInt('fjalekryq_playing_level', level);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const GameScreen(),
    )).then((_) {
      if (!mounted) return;
      final p = context.read<SharedPreferences>();
      setState(() {
        _level = p.getInt(_levelKey) ?? 1;
        _inProgress = p.getBool('fjalekryq_in_progress_$_level') ?? false;
      });
    });
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
    final statusBarH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
            // Header pinned at top
            _buildHeader(dailyAvailable, statusBarH),

            // Main content
            Positioned.fill(
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Space for the header
                        const SizedBox(height: 60),

                        // ── Daily + Leaderboard cards (full-width, stacked)
                        _buildCards(),

                        const SizedBox(height: 14),

                        // Daily offer — inline so it never collides with
                        // the cards above or the logo below.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DailyOfferBanner(
                              offer: offerForPrefs(
                                  context.read<SharedPreferences>()),
                              onTap: _openDailyOffer,
                            ),
                          ),
                        ),

                        const Spacer(flex: 4),

                        // Logo + subtitle (static — no breathing/scale).
                        _buildLogoSection(),

                        const Spacer(flex: 3),

                        // ── Level pill CTA ───────────────────────────────────
                        _buildLevelButton(),

                        const SizedBox(height: 36),
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

  Widget _buildHeader(bool dailyAvailable, double statusBarHeight) {
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
        color: Colors.transparent,
        child: Row(
          children: [
            // Daily reward — left
            _DailyRewardButton(
              onTap: _openDailyReward,
              available: dailyAvailable,
              pulseController: _pulseController,
            ),
            const Spacer(),
            // Shop — sits immediately left of settings so the right
            // cluster reads as a tidy pair of utility actions.
            _HeaderButton(
              icon: Icons.storefront_rounded,
              onTap: _openShop,
            ),
            const SizedBox(width: 10),
            // Settings — right edge
            _HeaderButton(
              icon: Icons.settings,
              onTap: _openSettings,
            ),
          ],
        ),
      ),
    );
  }

  // ── Daily + Leaderboard cards (full-width, glass-morphism) ────────────────

  Widget _buildCards() {
    final streak = context.watch<DailyPuzzleService>().currentStreak;
    final now = DateTime.now();
    final months = [
      'Janar', 'Shkurt', 'Mars', 'Prill', 'Maj', 'Qershor',
      'Korrik', 'Gusht', 'Shtator', 'Tetor', 'Nëntor', 'Dhjetor',
    ];
    final dateLabel = '${months[now.month - 1]} ${now.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // IntrinsicHeight forces both cards to match the taller one's
      // height. Without it, `CrossAxisAlignment.stretch` on a Row whose
      // parent (the main Column) has unbounded height fails the layout
      // pass with a `RenderBox was not laid out` assertion.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HomeCard(
                accent: const Color(0xFF60A5FA),
                icon: Icons.today_rounded,
                label: 'SFIDA DITORE',
                title: dateLabel,
                buttonLabel: streak > 0 ? 'Vazhdo' : 'Luaj',
                badge: streak > 0 ? '🔥 $streak' : null,
                onTap: _openDailyPuzzle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeCard(
                accent: AppColors.purpleAccent,
                icon: Icons.emoji_events_rounded,
                label: 'RENDITJA',
                // No title for the leaderboard card — the label alone is
                // enough, and "Tabelë Kryesore" was redundant alongside
                // the trophy icon.
                title: null,
                buttonLabel: 'Shiko',
                onTap: _openLeaderboard,
              ),
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
        const PuzzleLogo(size: 140),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4, height: 4,
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
              width: 4, height: 4,
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

  Widget _buildLevelButton() {
    final label = _inProgress ? 'Vazhdo Nivelin $_level' : 'Niveli $_level';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _openGame,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gold, Color(0xFFFFD86B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: AppFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.backgroundDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Home card widget ──────────────────────────────────────────────────────────

class _HomeCard extends StatelessWidget {
  /// Accent color that tints the border, glow, icon, and CTA button.
  final Color accent;
  final IconData icon;
  final String label;
  /// Optional secondary line under [label] (e.g. today's date for the
  /// daily card). Pass `null` to omit it — the leaderboard card uses
  /// this so the trophy icon + label stand on their own.
  final String? title;
  final String buttonLabel;
  final String? badge;
  final VoidCallback onTap;

  const _HomeCard({
    required this.accent,
    required this.icon,
    required this.label,
    required this.title,
    required this.buttonLabel,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Vertical layout — icon + headline at top, CTA pinned at the
    // bottom via Spacer so the two cards present a consistent button
    // baseline even when one card has no subtitle. The outer Row uses
    // IntrinsicHeight so this fills the matched card height.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.38),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top row: icon on the left, optional streak badge on the right
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: AppFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // The big label (e.g. "SFIDA DITORE", "RENDITJA") — this is
            // now the dominant headline of the card.
            Text(
              label,
              style: AppFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: Colors.white,
              ).copyWith(height: 1.1),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (title != null) ...[
              const SizedBox(height: 4),
              Text(
                title!,
                style: AppFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Spacer pushes the CTA to the bottom of the card so both
            // cards' buttons share a baseline even when one card has no
            // subtitle.
            const Spacer(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: Text(
                  buttonLabel,
                  style: AppFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
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
