import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/coin_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/glass_button.dart';
import '../level_map/level_map_screen.dart';
import '../game/game_screen.dart';
import '../settings/settings_sheet.dart';
import '../shop/daily_reward_sheet.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  final _rng = Random();
  late List<_BgTile> _bgTiles;
  Timer? _bgSwapTimer;
  int _level = 1;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<SharedPreferences>();
    _level = prefs.getInt(_levelKey) ?? 1;
    if (_level < 1) _level = 1;

    _bgTiles = _createBgTiles();
    _startBgSwaps();
  }

  @override
  void dispose() {
    _bgSwapTimer?.cancel();
    super.dispose();
  }

  List<_BgTile> _createBgTiles() {
    final tiles = <_BgTile>[];
    final rows = [5.0, 38.0, 72.0];
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < 5; c++) {
        final i = r * 5 + c;
        tiles.add(_BgTile(
          id: i,
          letter: _letters[_rng.nextInt(_letters.length)],
          x: 6 + c * 20 + (_rng.nextDouble() - 0.5) * 8,
          y: rows[r] + (_rng.nextDouble() - 0.5) * 10,
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
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const LevelMapScreen(),
    ));
  }

  void _startTutorial() {
    final prefs = context.read<SharedPreferences>();
    prefs.setBool('fjalekryq_force_tutorial', true);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const GameScreen(),
    ));
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  void _openDailyReward() {
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

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1B40), Color(0xFF142452)],
              ),
            ),
          ),

          // Animated background tiles
          ..._bgTiles.map((tile) => AnimatedPositioned(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                left: tile.x / 100 * MediaQuery.of(context).size.width,
                top: tile.y / 100 * MediaQuery.of(context).size.height,
                child: Opacity(
                  opacity: 0.12,
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

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Daily reward button
                      GestureDetector(
                        onTap: _openDailyReward,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.card_giftcard, color: Colors.white70, size: 20),
                            ),
                            if (dailyAvailable)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppColors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Settings button
                      GestureDetector(
                        onTap: _openSettings,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.settings, color: Colors.white70, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Logo area
                Column(
                  children: [
                    // Logo text (placeholder — replace with Image.asset when logo is available)
                    const Text(
                      'FJALËKRYQ',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LOJA E FJALËVE SHQIP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // CTA buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      GlassButton(
                        label: 'LUAJ',
                        icon: Icons.play_arrow,
                        onTap: _openLevelMap,
                        expanded: true,
                        height: 52,
                      ),
                      const SizedBox(height: 12),
                      GlassButton(
                        label: 'Si të luash',
                        icon: Icons.info_outline,
                        onTap: _startTutorial,
                        color: AppColors.surface,
                        expanded: true,
                        height: 46,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Social icons footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialIcon(Icons.camera_alt_outlined),
                      Container(
                        width: 1, height: 16,
                        color: Colors.white12,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      _socialIcon(Icons.music_note_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white38, size: 18),
    );
  }
}
