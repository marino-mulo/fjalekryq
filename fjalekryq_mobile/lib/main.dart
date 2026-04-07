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

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();

  // Pre-generate puzzles in the background
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
      ),
      home: const HomeScreen(),
    );
  }
}
