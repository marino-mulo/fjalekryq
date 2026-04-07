import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/coin_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/glass_button.dart';
import '../level_map/level_map_screen.dart';
import '../game/game_screen.dart';
import '../settings/settings_sheet.dart';
import '../shop/daily_reward_sheet.dart';
import 'leaderboard_section.dart';

const _levelKey = 'fjalekryq_level';
const _letters = 'ABCÇDEHIMNOPRSTUVXZ';
const _bgColors = [AppColors.cellGreen, AppColors.gold, AppColors.cellGrey];

class _BgTile {
  final int id;
  String letter;
  double x, y;
  Color color;
  final double delay;

  _BgTile({
    required this.id,
    required this.letter,
    required this.x,
    required this.y,
    required this.color,
    required this.delay,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late List<_BgTile> _bgTiles;
  Timer? _bgSwapTimer;
  int _level = 1;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<SharedPreferences>();
    _level = prefs.getInt(_levelKey) ?? 1;
    if (_level < 1) _level = 1;

    _bgTiles = _createBgTiles();
    _startBgSwaps();

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

    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgSwapTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  List<_BgTile> _createBgTiles() {
    final tiles = <_BgTile>[];
    final rows = [5.0, 28.0, 52.0, 76.0];
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < 5; c++) {
        final i = r * 5 + c;
        tiles.add(_BgTile(
          id: i,
          letter: _letters[_rng.nextInt(_letters.length)],
          x: 4 + c * 20 + (_rng.nextDouble() - 0.5) * 10,
          y: rows[r] + (_rng.nextDouble() - 0.5) * 8,
          color: _bgColors[i % 3],
          delay: _rng.nextDouble() * 4,
        ));
      }
    }
    return tiles;
  }

  void _startBgSwaps() {
    _bgSwapTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      final i = _rng.nextInt(_bgTiles.length);
      var j = _rng.nextInt(_bgTiles.length - 1);
      if (j >= i) j++;
      setState(() {
        final tmpX = _bgTiles[i].x;
        final tmpY = _bgTiles[i].y;
        _bgTiles[i].x = _bgTiles[j].x;
        _bgTiles[i].y = _bgTiles[j].y;
        _bgTiles[j].x = tmpX;
        _bgTiles[j].y = tmpY;
      });
    });
  }

  void _openLevelMap() {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const LevelMapScreen(),
    ));
  }

  void _startTutorial() {
    HapticFeedback.lightImpact();
    final prefs = context.read<SharedPreferences>();
    prefs.setBool('fjalekryq_force_tutorial', true);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const GameScreen(),
    ));
  }

  void _openSettings() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
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

  @override
  Widget build(BuildContext context) {
    final coinService = context.watch<CoinService>();
    final dailyAvailable = coinService.peekDaily() != null;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient with subtle radial glow
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF07152F), Color(0xFF0D1B40), Color(0xFF142452)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Subtle center glow
          Positioned(
            top: screenSize.height * 0.2,
            left: screenSize.width * 0.15,
            child: Container(
              width: screenSize.width * 0.7,
              height: screenSize.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cellGreen.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Animated background tiles
          ..._bgTiles.map((tile) => AnimatedPositioned(
                key: ValueKey(tile.id),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                left: tile.x / 100 * screenSize.width,
                top: tile.y / 100 * screenSize.height,
                child: Opacity(
                  opacity: 0.10,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tile.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tile.letter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              )),

          // Main content with entrance animation
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header row
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _HeaderButton(
                              icon: Icons.card_giftcard,
                              onTap: _openDailyReward,
                              showDot: dailyAvailable,
                            ),
                            const Spacer(),
                            _HeaderButton(
                              icon: Icons.settings,
                              onTap: _openSettings,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),

                    // Logo area
                    SliverToBoxAdapter(child: _buildLogoSection()),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),

                    // CTA buttons
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            GlassButton(
                              label: 'LUAJ',
                              icon: Icons.play_arrow,
                              onTap: _openLevelMap,
                              expanded: true,
                              height: 54,
                            ),
                            const SizedBox(height: 14),
                            GlassButton(
                              label: 'Si të luash',
                              icon: Icons.info_outline,
                              onTap: _startTutorial,
                              color: AppColors.surface,
                              expanded: true,
                              height: 48,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 28)),

                    // Leaderboard
                    const SliverToBoxAdapter(
                      child: LeaderboardSection(),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // Social icons footer
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _socialIcon(Icons.camera_alt_outlined),
                            Container(
                              width: 1, height: 16,
                              color: Colors.white10,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            _socialIcon(Icons.music_note_outlined),
                          ],
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
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Mini crossword logo
        _buildMiniCrossword(),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            'FJALËKRYQ',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(AppColors.gold),
            const SizedBox(width: 10),
            Text(
              'LOJA E FJALËVE SHQIP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(width: 10),
            _dot(AppColors.gold),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCrossword() {
    final tiles = [
      [('F', AppColors.cellGreen), ('J', AppColors.cellYellow), ('A', AppColors.cellGrey)],
      [null, ('K', AppColors.cellGreen), null],
      [null, ('R', AppColors.cellYellow), null],
    ];

    return Column(
      children: List.generate(3, (r) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (c) {
          final tile = tiles[r][c];
          if (tile == null) {
            return const SizedBox(width: 40, height: 40);
          }
          return Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: tile.$2,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: tile.$2.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              tile.$1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          );
        }),
      )),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 5, height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _socialIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Icon(icon, color: Colors.white30, size: 18),
    );
  }
}

/// Reusable header icon button with optional notification dot.
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(icon, color: Colors.white60, size: 20),
          ),
          if (showDot)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.greenAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
