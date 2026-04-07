import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_helper.dart';
import 'core/database/repositories/user_repository.dart';
import 'core/database/repositories/coins_repository.dart';
import 'core/database/repositories/settings_repository.dart';
import 'core/database/repositories/progress_repository.dart';
import 'core/database/repositories/game_state_repository.dart';
import 'core/database/repositories/level_repository.dart';
import 'core/database/repositories/notification_repository.dart';
import 'core/database/repositories/achievement_repository.dart';
import 'core/database/repositories/ad_reward_repository.dart';
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

  // Initialize SQLite database
  final dbHelper = DatabaseHelper();
  await dbHelper.database; // ensure DB is created

  // Create repositories
  final userRepo = UserRepository(dbHelper);
  final coinsRepo = CoinsRepository(dbHelper);
  final settingsRepo = SettingsRepository(dbHelper);
  final progressRepo = ProgressRepository(dbHelper);
  final gameStateRepo = GameStateRepository(dbHelper);
  final levelRepo = LevelRepository(dbHelper);
  final notificationRepo = NotificationRepository(dbHelper);
  final achievementRepo = AchievementRepository(dbHelper);
  final adRewardRepo = AdRewardRepository(dbHelper);

  // Get or create the local user
  final localUser = await userRepo.getOrCreateLocalUser();
  final userId = localUser.id!;

  // Initialize services backed by SQLite
  final coinService = CoinService(coinsRepo, userId);
  await coinService.init();

  final settingsService = SettingsService(settingsRepo, userId);
  await settingsService.init();

  // Migrate SharedPreferences data to SQLite (one-time)
  await _migrateFromSharedPrefs(prefs, coinsRepo, settingsRepo, progressRepo, userId);

  final puzzleStore = LevelPuzzleStore();
  puzzleStore.generateAll();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: coinService),
        ChangeNotifierProvider.value(value: settingsService),
        Provider<LevelPuzzleStore>.value(value: puzzleStore),
        Provider<SharedPreferences>.value(value: prefs),
        Provider<DatabaseHelper>.value(value: dbHelper),
        Provider<int>.value(value: userId),
        Provider<ProgressRepository>.value(value: progressRepo),
        Provider<GameStateRepository>.value(value: gameStateRepo),
        Provider<UserRepository>.value(value: userRepo),
        Provider<LevelRepository>.value(value: levelRepo),
        Provider<NotificationRepository>.value(value: notificationRepo),
        Provider<AchievementRepository>.value(value: achievementRepo),
        Provider<AdRewardRepository>.value(value: adRewardRepo),
      ],
      child: const FjalekryqApp(),
    ),
  );
}

/// One-time migration from SharedPreferences to SQLite.
Future<void> _migrateFromSharedPrefs(
  SharedPreferences prefs,
  CoinsRepository coinsRepo,
  SettingsRepository settingsRepo,
  ProgressRepository progressRepo,
  int userId,
) async {
  const migrationKey = 'fjalekryq_sqlite_migrated';
  if (prefs.getBool(migrationKey) == true) return;

  // Migrate coins
  final oldCoins = prefs.getInt('fjalekryq_coins');
  if (oldCoins != null) {
    final coins = await coinsRepo.getOrCreate(userId);
    coins.balance = oldCoins;
    coins.lastDailyClaim = prefs.getString('fjalekryq_last_login');
    coins.streakDay = prefs.getInt('fjalekryq_login_streak') ?? 0;
    await coinsRepo.update(coins.id!, coins);
  }

  // Migrate settings
  final hasMusicPref = prefs.containsKey('fjalekryq_music');
  if (hasMusicPref) {
    final settings = await settingsRepo.getOrCreate(userId);
    settings.music = prefs.getBool('fjalekryq_music') ?? true;
    settings.sound = prefs.getBool('fjalekryq_sound') ?? true;
    settings.notification = prefs.getBool('fjalekryq_notif') ?? true;
    settings.emailNotification = prefs.getBool('fjalekryq_email_notif') ?? true;
    await settingsRepo.saveSettings(settings);
  }

  // Migrate progress/stars
  final currentLevel = prefs.getInt('fjalekryq_level') ?? 1;
  for (int level = 1; level < currentLevel; level++) {
    final stars = prefs.getInt('fjalekryq_stars_$level') ?? 0;
    await progressRepo.upsert(userId, level, stars: stars, completed: true);
  }

  await prefs.setBool(migrationKey, true);
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
