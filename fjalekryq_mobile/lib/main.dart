import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';

import 'core/database/database_helper.dart';
import 'core/database/repositories/user_repository.dart';
import 'core/database/repositories/coins_repository.dart';
import 'core/database/repositories/settings_repository.dart';
import 'core/database/repositories/progress_repository.dart';
import 'core/database/repositories/game_state_repository.dart';
import 'core/database/repositories/notification_repository.dart';
import 'core/database/repositories/user_generated_level_repository.dart';
import 'core/database/repositories/achievement_repository.dart';
import 'core/database/repositories/ad_reward_repository.dart';
import 'core/services/coin_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/audio_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/level_puzzle_store.dart';
import 'core/services/daily_puzzle_service.dart';
import 'core/services/sync_service.dart';
import 'core/network/remote_auth_repository.dart';
import 'core/network/remote_coins_repository.dart';
import 'core/network/remote_level_repository.dart';
import 'core/network/remote_progress_repository.dart';
import 'core/network/remote_streak_repository.dart';
import 'core/network/remote_daily_puzzle_repository.dart';
import 'core/network/hybrid_progress_repository.dart';
import 'core/network/hybrid_streak_repository.dart';
import 'core/network/hybrid_daily_puzzle_repository.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'shared/constants/theme.dart';
import 'shared/widgets/app_loading_view.dart';
import 'shared/widgets/lojralogjike_splash.dart';

late final Future<_AppServices> _initFuture;

const _onboardingDoneKey = 'fjalekryq_onboarding_done';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent GoogleFonts from making network requests — use bundled fallback
  GoogleFonts.config.allowRuntimeFetching = false;

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // iOS 14+: request App Tracking Transparency permission before AdMob init.
  // On Android the package is a no-op (returns TrackingStatus.authorized).
  if (Platform.isIOS) {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // Small delay so the ATT dialog appears after the app is fully visible.
      await Future.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }

  // Initialize AdMob SDK after ATT decision (so consent state is known).
  await MobileAds.instance.initialize();

  _initFuture = _initializeApp();

  runApp(const FjalekryqApp());
}

Future<_AppServices> _initializeApp() async {
  final prefs = await SharedPreferences.getInstance();

  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  final userRepo = UserRepository(dbHelper);
  final coinsRepo = CoinsRepository(dbHelper);
  final settingsRepo = SettingsRepository(dbHelper);
  // Hybrid repos: write-through to the server so the leaderboard and
  // cross-device progress stay populated. Reads stay local for speed;
  // the remote sync is best-effort and silently retried on next write.
  final progressRepo = HybridProgressRepository(dbHelper, RemoteProgressRepository());
  final gameStateRepo = GameStateRepository(dbHelper);
  final userGeneratedLevelRepo = UserGeneratedLevelRepository(dbHelper);
  final notificationRepo = NotificationRepository(dbHelper);
  final achievementRepo = AchievementRepository(dbHelper);
  final adRewardRepo = AdRewardRepository(dbHelper);
  final dailyPuzzleRepo = HybridDailyPuzzleRepository(dbHelper, RemoteDailyPuzzleRepository());
  final dailyStreakRepo = HybridStreakRepository(dbHelper, RemoteStreakRepository());

  final localUser = await userRepo.getOrCreateLocalUser();
  final userId = localUser.id!;

  final coinService = CoinService(coinsRepo, userId);
  final settingsService = SettingsService(settingsRepo, userId);
  final dailyPuzzleService = DailyPuzzleService(dailyPuzzleRepo, dailyStreakRepo, userId);

  // Local-only work must finish before we hand the UI over.
  await Future.wait([
    coinService.init(),
    settingsService.init(),
    _migrateFromSharedPrefs(prefs, coinsRepo, settingsRepo, progressRepo, userId),
  ]);

  // Remote-touching work gets a hard cap so the splash can never hang
  // when the API is flaky (timeouts + TCP resets can otherwise stack up
  // to tens of seconds). Whatever hasn't finished keeps running in the
  // background; the UI starts from local cache and syncs on the fly.
  try {
    await Future.wait([
      dailyPuzzleService.init(),
      // Guests are first-class API citizens — if no session exists yet,
      // create one in the background so every protected endpoint
      // (leaderboard, coins, progress, daily puzzle…) works out of the
      // box. Silent failure is fine: the UI already has offline paths.
      RemoteAuthRepository().ensureSession().then<void>((_) {}),
    ]).timeout(const Duration(seconds: 6));
  } catch (_) {
    // API is unreachable / crashing. Continue booting — the app is
    // fully usable from the local SQLite cache. Any pending remote
    // calls keep running; they'll just settle later.
  }

  // Once auth is settled, reconcile anything that was written locally
  // while offline (level completions, coin balance) with the server.
  // Runs in the background — the UI doesn't wait on it. A listener
  // fires the same sync whenever connectivity flips back online.
  final syncService = SyncService(
    userId:          userId,
    progressRepo:    progressRepo,
    remoteProgress:  RemoteProgressRepository(),
    remoteCoins:     RemoteCoinsRepository(),
    coinService:     coinService,
    connectivity:    ConnectivityService.instance,
  )..start();
  unawaited(syncService.syncAll());

  // Don't block startup with font loading — let it happen lazily
  return _AppServices(
    prefs: prefs,
    dbHelper: dbHelper,
    userId: userId,
    coinService: coinService,
    settingsService: settingsService,
    audioService: AudioService(settingsService),
    adService: AdService(adRewardRepo, userId, prefs),
    dailyPuzzleService: dailyPuzzleService,
    puzzleStore: LevelPuzzleStore(
      RemoteLevelRepository(),
      userGeneratedLevelRepo,
      userId,
    ),
    progressRepo: progressRepo,
    gameStateRepo: gameStateRepo,
    userRepo: userRepo,
    userGeneratedLevelRepo: userGeneratedLevelRepo,
    notificationRepo: notificationRepo,
    achievementRepo: achievementRepo,
    adRewardRepo: adRewardRepo,
    coinsRepo: coinsRepo,
  );
}

class _AppServices {
  final SharedPreferences prefs;
  final DatabaseHelper dbHelper;
  final int userId;
  final CoinService coinService;
  final SettingsService settingsService;
  final AudioService audioService;
  final AdService adService;
  final DailyPuzzleService dailyPuzzleService;
  final LevelPuzzleStore puzzleStore;
  final ProgressRepository progressRepo;
  final GameStateRepository gameStateRepo;
  final UserRepository userRepo;
  final UserGeneratedLevelRepository userGeneratedLevelRepo;
  final NotificationRepository notificationRepo;
  final AchievementRepository achievementRepo;
  final AdRewardRepository adRewardRepo;
  final CoinsRepository coinsRepo;

  const _AppServices({
    required this.prefs,
    required this.dbHelper,
    required this.userId,
    required this.coinService,
    required this.settingsService,
    required this.audioService,
    required this.adService,
    required this.dailyPuzzleService,
    required this.puzzleStore,
    required this.progressRepo,
    required this.gameStateRepo,
    required this.userRepo,
    required this.userGeneratedLevelRepo,
    required this.notificationRepo,
    required this.achievementRepo,
    required this.adRewardRepo,
    required this.coinsRepo,
  });

  List<SingleChildWidget> get providers => [
    ChangeNotifierProvider.value(value: coinService),
    ChangeNotifierProvider.value(value: settingsService),
    ChangeNotifierProvider.value(value: adService),
    ChangeNotifierProvider.value(value: dailyPuzzleService),
    ChangeNotifierProvider<ConnectivityService>.value(
      value: ConnectivityService.instance,
    ),
    Provider<AudioService>.value(value: audioService),
    Provider<LevelPuzzleStore>.value(value: puzzleStore),
    Provider<SharedPreferences>.value(value: prefs),
    Provider<DatabaseHelper>.value(value: dbHelper),
    Provider<int>.value(value: userId),
    Provider<ProgressRepository>.value(value: progressRepo),
    Provider<GameStateRepository>.value(value: gameStateRepo),
    Provider<UserRepository>.value(value: userRepo),
    Provider<UserGeneratedLevelRepository>.value(value: userGeneratedLevelRepo),
    Provider<NotificationRepository>.value(value: notificationRepo),
    Provider<AchievementRepository>.value(value: achievementRepo),
    Provider<AdRewardRepository>.value(value: adRewardRepo),
  ];
}

Future<void> _migrateFromSharedPrefs(
  SharedPreferences prefs,
  CoinsRepository coinsRepo,
  SettingsRepository settingsRepo,
  ProgressRepository progressRepo,
  int userId,
) async {
  const migrationKey = 'fjalekryq_sqlite_migrated';
  if (prefs.getBool(migrationKey) == true) return;

  final oldCoins = prefs.getInt('fjalekryq_coins');
  if (oldCoins != null) {
    final coins = await coinsRepo.getOrCreate(userId);
    coins.balance = oldCoins;
    coins.lastDailyClaim = prefs.getString('fjalekryq_last_login');
    coins.streakDay = prefs.getInt('fjalekryq_login_streak') ?? 0;
    await coinsRepo.update(coins.id!, coins);
  }

  final hasMusicPref = prefs.containsKey('fjalekryq_music');
  if (hasMusicPref) {
    final settings = await settingsRepo.getOrCreate(userId);
    settings.music = prefs.getBool('fjalekryq_music') ?? true;
    settings.sound = prefs.getBool('fjalekryq_sound') ?? true;
    settings.notification = prefs.getBool('fjalekryq_notif') ?? true;
    settings.emailNotification = prefs.getBool('fjalekryq_email_notif') ?? true;
    await settingsRepo.saveSettings(settings);
  }

  final currentLevel = prefs.getInt('fjalekryq_level') ?? 1;
  for (int level = 1; level < currentLevel; level++) {
    await progressRepo.upsert(userId, level, completed: true);
  }

  await prefs.setBool(migrationKey, true);
}

// ── App ────────────────────────────────────────────────────

class FjalekryqApp extends StatefulWidget {
  const FjalekryqApp({super.key});

  @override
  State<FjalekryqApp> createState() => _FjalekryqAppState();
}

class _FjalekryqAppState extends State<FjalekryqApp> {
  _AppServices? _services;
  // Controls the first-launch brand splash. Flips to true after
  // [_brandSplashDuration] so the loading view can take over.
  bool _brandSplashDone = false;

  static const _brandSplashDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _initFuture.then((s) {
      if (mounted) setState(() => _services = s);
    });
    Future.delayed(_brandSplashDuration, () {
      if (mounted) setState(() => _brandSplashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _services;

    // ONE MaterialApp — never recreated.
    // `builder` injects providers above the Navigator so bottom sheets see them.
    // `home` swaps brand splash → loading view → home as state advances.
    return MaterialApp(
      debugShowCheckedModeBanner: AppConfig.showDebugBanner,
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
      builder: s != null
          ? (_, child) => MultiProvider(providers: s.providers, child: child!)
          : null,
      home: !_brandSplashDone
          ? const LojraLogjikeSplash()
          : s == null
              ? const AppLoadingView()
              : (s.prefs.getBool(_onboardingDoneKey) ?? false)
                  ? const HomeScreen()
                  : const OnboardingScreen(),
    );
  }
}

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

