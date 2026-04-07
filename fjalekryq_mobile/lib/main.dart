import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/coin_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/level_puzzle_store.dart';
import 'features/home/home_screen.dart';
import 'shared/constants/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();

  final puzzleStore = LevelPuzzleStore();
  puzzleStore.generateAll();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CoinService(prefs)),
        ChangeNotifierProvider(create: (_) => SettingsService(prefs)),
        Provider<LevelPuzzleStore>.value(value: puzzleStore),
        Provider<SharedPreferences>.value(value: prefs),
      ],
      child: const FjalekryqApp(),
    ),
  );
}

class FjalekryqApp extends StatelessWidget {
  const FjalekryqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fjalekryq',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SlideUpTransitionBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Custom slide-up page transition for a mobile game feel.
class _SlideUpTransitionBuilder extends PageTransitionsBuilder {
  const _SlideUpTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      ),
    );
  }
}

// ── Splash Screen ──────────────────────────────────────────

const _splashLetters = 'ABCÇDEHIMNOPRSTUVXZË';
const _splashColors = [AppColors.cellGreen, AppColors.gold, AppColors.cellGrey];

class _SplashTile {
  final String letter;
  final Color color;
  final double left;
  final double top;
  final int index;

  const _SplashTile({
    required this.letter,
    required this.color,
    required this.left,
    required this.top,
    required this.index,
  });
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<double> _scaleAnim;
  late List<_SplashTile> _tiles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    _tiles = List.generate(20, (i) => _SplashTile(
      letter: _splashLetters[_rng.nextInt(_splashLetters.length)],
      color: _splashColors[i % 3],
      left: 0.05 + (_rng.nextDouble() * 0.85),
      top: 0.1 + (_rng.nextDouble() * 0.75),
      index: i,
    ));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fadeIn = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );
    _fadeOut = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF07152F), Color(0xFF0D1B40)],
              ),
            ),
            child: Stack(
              children: [
                // Background letter tiles floating in
                ..._tiles.map((tile) {
                  final delay = tile.index * 0.03;
                  final tileProgress = (_controller.value - delay).clamp(0.0, 1.0);
                  final opacity = (tileProgress * 2).clamp(0.0, 0.15);
                  final scale = 0.5 + tileProgress * 0.5;

                  return Positioned(
                    left: tile.left * size.width,
                    top: tile.top * size.height,
                    child: Opacity(
                      opacity: opacity * _fadeOut.value,
                      child: Transform.scale(
                        scale: scale,
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
                    ),
                  );
                }),

                // Center logo
                Center(
                  child: Opacity(
                    opacity: _fadeIn.value * _fadeOut.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo crossword tiles
                          _buildLogoTiles(),
                          const SizedBox(height: 16),
                          Text(
                            'FJALËKRYQ',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(
                                  color: AppColors.cellGreen.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'LOJA E FJALËVE SHQIP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 3,
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
        },
      ),
    );
  }

  Widget _buildLogoTiles() {
    // 3x3 mini crossword: F J A / _ K _ / _ R _
    final tiles = [
      ['F', 'J', 'A'],
      ['', 'K', ''],
      ['', 'R', ''],
    ];
    final colors = [
      [AppColors.cellGreen, AppColors.cellYellow, AppColors.cellGrey],
      [null, AppColors.cellGreen, null],
      [null, AppColors.cellYellow, null],
    ];

    return Column(
      children: List.generate(3, (r) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (c) {
          if (tiles[r][c].isEmpty) {
            return const SizedBox(width: 40, height: 40);
          }
          return Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: colors[r][c],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              tiles[r][c],
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
}
