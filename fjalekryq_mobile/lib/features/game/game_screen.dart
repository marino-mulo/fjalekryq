import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/puzzle.dart';
import '../../core/models/level_config.dart';
import '../../core/services/game_service.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/level_puzzle_store.dart';
import '../../core/database/repositories/game_state_repository.dart';
import '../../core/database/repositories/progress_repository.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/coin_badge.dart';
import '../../shared/widgets/shiko_button.dart';
import '../tutorial/tutorial_overlay.dart';
import '../shop/shop_sheet.dart';
import 'widgets/game_board.dart';

const _levelKey = 'fjalekryq_level';
const _playingLevelKey = 'fjalekryq_playing_level';
const _tutorialKey = 'fjalekryq_tutorial_done';
const _starsKeyPrefix = 'fjalekryq_stars_';

/// Tutorial puzzle: MALI (vertical), BORA (horizontal), DETI (horizontal)
final _tutorialPuzzle = Wordle7Puzzle(
  gridSize: 7,
  solution: [
    ['X', 'X', 'X', 'M', 'X', 'X', 'X'],
    ['B', 'O', 'R', 'A', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'L', 'X', 'X', 'X'],
    ['D', 'E', 'T', 'I', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
  ],
  words: [
    const WordEntry(word: 'MALI', row: 0, col: 3, direction: WordDirection.vertical),
    const WordEntry(word: 'BORA', row: 1, col: 0, direction: WordDirection.horizontal),
    const WordEntry(word: 'DETI', row: 3, col: 0, direction: WordDirection.horizontal),
  ],
  swapLimit: 8,
  hash: 'tutorial_v1',
);

final _tutorialInitialGrid = [
  ['X', 'X', 'X', 'B', 'X', 'X', 'X'],
  ['M', 'O', 'R', 'A', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'L', 'X', 'X', 'X'],
  ['I', 'D', 'E', 'T', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
];

const _praises = ['Bravo!', 'Të lumtë!', 'Shkëlqyeshëm!', 'Fantastike!', 'Mahnitëse!'];

/// Coins earned per difficulty on first clear.
const _difficultyCoinMap = {
  Difficulty.easy: 20,
  Difficulty.medium: 35,
  Difficulty.hard: 50,
  Difficulty.expert: 80,
};

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameService _game;
  late SharedPreferences _prefs;
  late AudioService _audio;
  late int _userId;

  // Tutorial state
  bool _isTutorial = false;
  int _tutorialPhase = 0; // 0=off, 1-9
  List<({int row, int col})> _tutorialHighlightCells = [];

  // Completion state
  bool _isCompleted = false;
  String _completedPraise = 'Bravo!';
  int _completedStars = 0;
  int _coinsEarned = 0;

  // Loading state
  bool _isLoading = false;

  // Insufficient coins banner
  String? _insufficientType; // 'hint' | 'solve' | null

  // Ad state
  bool _loadingAd = false;
  bool _winCoinsDoubled = false;
  bool _continuedAfterLoss = false;

  @override
  void initState() {
    super.initState();
    _prefs = context.read<SharedPreferences>();
    _audio = context.read<AudioService>();
    _userId = context.read<int>();
    final gameStateRepo = context.read<GameStateRepository>();
    final progressRepo = context.read<ProgressRepository>();
    _game = GameService(_prefs, gameStateRepo, progressRepo, _userId);
    _game.addListener(_onGameChanged);

    _initializeGame();
  }

  @override
  void dispose() {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (!mounted) return;

    // Auto-advance tutorial phases
    if (_isTutorial) {
      if (_tutorialPhase == 2 && _game.totalSwapCount > 0) {
        _setTutorialPhase(3);
      } else if (_tutorialPhase == 5 && _game.hintCount > 0) {
        _setTutorialPhase(6);
      } else if (_tutorialPhase == 8 && _game.solveWordCooldown) {
        _setTutorialPhase(9);
      }
    }

    // Auto-trigger win
    if (_game.gameWon && !_isCompleted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _onWin();
      });
    }

    // Detect loss
    if (_game.gameLost && !_isCompleted) {
      _audio.play(Sfx.lose);
    }

    setState(() {});
  }

  void _initializeGame() async {
    final forceTutorial = _prefs.getBool('fjalekryq_force_tutorial') ?? false;
    if (forceTutorial) _prefs.remove('fjalekryq_force_tutorial');

    final level = _prefs.getInt(_levelKey) ?? 1;
    final tutorialDone = _prefs.getBool(_tutorialKey) ?? false;

    if ((level == 1 && !tutorialDone) || forceTutorial) {
      _isTutorial = true;
      _game.setTutorialMode(true);
      _game.restorePuzzle(
        _tutorialPuzzle,
        _tutorialInitialGrid.map((r) => List<String>.from(r)).toList(),
        0, 0, 0,
      );
      _setTutorialPhase(1);
    } else {
      final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
      final saved = await _game.loadSavedState(playingLevel);
      if (saved != null && saved.puzzle.hash != 'tutorial_v1' && saved.level == playingLevel) {
        _game.restorePuzzle(saved.puzzle, saved.grid, saved.swapCount, saved.hintCount, saved.totalSwapCount, playingLevel);
      } else {
        _loadPuzzle();
      }
    }
  }

  void _loadPuzzle() {
    setState(() => _isLoading = true);
    _isCompleted = false;
    _winCoinsDoubled = false;
    _continuedAfterLoss = false;
    _loadingAd = false;
    _game.clearSavedState();

    final level = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    final puzzleStore = context.read<LevelPuzzleStore>();

    puzzleStore.generate(level).then((puzzle) {
      if (!mounted) return;
      if (puzzle != null) {
        _game.initPuzzle(puzzle, level: level);
      }
      setState(() => _isLoading = false);
    }).catchError((e) {
      if (!mounted) return;
      debugPrint('Puzzle generation failed: $e');
      setState(() => _isLoading = false);
    });
  }

  void _setTutorialPhase(int phase) {
    setState(() {
      _tutorialPhase = phase;
      if (phase == 2) {
        _tutorialHighlightCells = [(row: 0, col: 3), (row: 1, col: 0)];
      } else {
        _tutorialHighlightCells = [];
      }
    });
  }

  int _computeStars() {
    final rem = _game.swapsRemaining;
    if (rem >= 7) return 3;
    if (rem >= 3) return 2;
    return 1;
  }

  int get _previewStars {
    final rem = _game.swapsRemaining;
    if (rem >= 7) return 3;
    if (rem >= 3) return 2;
    return 1;
  }

  void _onWin() {
    if (_isCompleted) return;
    HapticFeedback.heavyImpact();
    _audio.play(Sfx.win);
    final coinService = context.read<CoinService>();
    _tutorialPhase = 0;
    _tutorialHighlightCells = [];
    _isCompleted = true;
    _completedPraise = _praises[DateTime.now().millisecond % _praises.length];
    final stars = _computeStars();
    _completedStars = stars;
    // Play star sounds with staggered delay
    for (int i = 0; i < stars; i++) {
      Future.delayed(Duration(milliseconds: 400 + i * 300), () => _audio.play(Sfx.star));
    }

    if (_isTutorial) {
      _coinsEarned = 0;
    } else {
      final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
      final progress = _prefs.getInt(_levelKey) ?? 1;

      // Save stars (keep best) — both SharedPrefs (for quick reads) and SQLite
      final starsKey = '$_starsKeyPrefix$playingLevel';
      final existing = _prefs.getInt(starsKey) ?? 0;
      final bestStars = stars > existing ? stars : existing;
      _prefs.setInt(starsKey, bestStars);
      _game.saveProgress(playingLevel, stars: bestStars, completed: true);

      // Award coins on first clear
      final isFirstClear = playingLevel >= progress;
      if (isFirstClear) {
        final diff = difficultyForLevel(playingLevel);
        _coinsEarned = _difficultyCoinMap[diff] ?? 10;
        coinService.add(_coinsEarned);
        Future.delayed(const Duration(milliseconds: 800), () => _audio.play(Sfx.coin));
      } else {
        _coinsEarned = 0;
      }

      // Advance progress
      if (isFirstClear && playingLevel < totalActiveLevels) {
        _prefs.setInt(_levelKey, playingLevel + 1);
      }
    }
    setState(() {});
  }

  void _onHint() {
    HapticFeedback.mediumImpact();
    final coinService = context.read<CoinService>();
    if (!_isTutorial) {
      if (!coinService.canAfford(hintCost)) {
        HapticFeedback.heavyImpact();
        _audio.play(Sfx.error);
        _showInsufficientCoins('hint');
        return;
      }
      coinService.spend(hintCost);
    }
    _audio.play(Sfx.hint);
    _game.hint();
  }

  void _onSolveWord() {
    HapticFeedback.mediumImpact();
    final coinService = context.read<CoinService>();
    if (!_isTutorial) {
      if (!coinService.canAfford(solveCost)) {
        HapticFeedback.heavyImpact();
        _audio.play(Sfx.error);
        _showInsufficientCoins('solve');
        return;
      }
      coinService.spend(solveCost);
    }
    _audio.play(Sfx.solve);
    _game.solveWord();
  }

  void _showInsufficientCoins(String type) {
    setState(() => _insufficientType = type);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _insufficientType = null);
    });
  }

  void _nextLevel() {
    if (_isTutorial) {
      _prefs.setBool(_tutorialKey, true);
      _isTutorial = false;
      _tutorialPhase = 0;
      _tutorialHighlightCells = [];
      _game.setTutorialMode(false);
      _loadPuzzle();
    } else {
      final progress = _prefs.getInt(_levelKey) ?? 1;
      _prefs.setInt(_playingLevelKey, progress);
      _loadPuzzle();
    }
  }

  void _restartLevel() {
    setState(() {
      _isCompleted = false;
      _winCoinsDoubled = false;
      _continuedAfterLoss = false;
      _loadingAd = false;
    });
    _game.resetPuzzle();
  }

  String get _difficultyLabel {
    final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    return difficultyLabel(difficultyForLevel(playingLevel));
  }

  Difficulty get _difficulty {
    final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    return difficultyForLevel(playingLevel);
  }

  Color get _difficultyColor {
    switch (_difficulty) {
      case Difficulty.easy:   return const Color(0xFF4ADE80);
      case Difficulty.medium: return const Color(0xFFFCD34D);
      case Difficulty.hard:   return const Color(0xFFFCA5A5);
      case Difficulty.expert: return const Color(0xFFE879F9);
    }
  }

  Color get _difficultyBorderColor {
    switch (_difficulty) {
      case Difficulty.easy:   return const Color(0xFF22C55E).withValues(alpha: 0.4);
      case Difficulty.medium: return const Color(0xFFEAB308).withValues(alpha: 0.4);
      case Difficulty.hard:   return const Color(0xFFEF4444).withValues(alpha: 0.4);
      case Difficulty.expert: return const Color(0xFFA855F7).withValues(alpha: 0.45);
    }
  }

  int get _nextLevelNumber {
    final progress = _prefs.getInt(_levelKey) ?? 1;
    return progress;
  }

  Color get _difficultyBgColor {
    switch (_difficulty) {
      case Difficulty.easy:   return const Color(0xFF22C55E).withValues(alpha: 0.2);
      case Difficulty.medium: return const Color(0xFFEAB308).withValues(alpha: 0.2);
      case Difficulty.hard:   return const Color(0xFFEF4444).withValues(alpha: 0.2);
      case Difficulty.expert: return const Color(0xFFA855F7).withValues(alpha: 0.25);
    }
  }

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final coinService = context.watch<CoinService>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background: linear gradient + golden radial glow ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0C1F4A), Color(0xFF123B86), Color(0xFF07152F)],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.08),
                  radius: 0.8,
                  colors: [
                    const Color(0xFFFFBA27).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.72],
                ),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(coinService),
                const SizedBox(height: 12),
                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  _buildInfoRow(),

                const SizedBox(height: 12),

                // Game board
                if (!_isLoading)
                  ListenableBuilder(
                    listenable: _game,
                    builder: (context, _) => GameBoard(
                      game: _game,
                      tutorialHighlight: _tutorialHighlightCells,
                      disableSwap: _isTutorial && (_tutorialPhase == 5 || _tutorialPhase == 8),
                    ),
                  )
                else
                  Expanded(child: _buildLoadingOverlay()),

                // Small space between board and controls
                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  const SizedBox(height: 12),

                // Bottom controls (solve/hint) — right after board
                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  _buildBottomControls(coinService),

                // Banners between buttons and completion/lost
                if (!_isCompleted && !_game.gameLost && !_isLoading) ...[
                  const SizedBox(height: 8),
                  if (_game.hintMessage.isNotEmpty && !_isTutorial && _insufficientType == null)
                    _buildInlineBanner(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Color(0xFFFFD86B), size: 15),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _game.hintMessage,
                              style: AppFonts.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFFD86B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      bgColor: const Color(0xFFC9B458).withValues(alpha: 0.2),
                      borderColor: const Color(0xFFFFBA27).withValues(alpha: 0.4),
                    ),
                  if (_insufficientType != null)
                    _buildInlineInsufficientBanner(),
                  if (_isTutorial && _tutorialPhase == 2)
                    _buildInlineBanner(
                      child: Text(
                        '👆 Kliko shkronjat për të bërë 1 lëvizje',
                        textAlign: TextAlign.center,
                        style: AppFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      bgColor: Colors.white.withValues(alpha: 0.12),
                      borderColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  if (_isTutorial && _tutorialPhase == 5)
                    _buildInlineBanner(
                      child: Text(
                        '💡 Kliko Ndihmën për $hintCost\$ — shkronjat, ruaj lëvizjet!',
                        textAlign: TextAlign.center,
                        style: AppFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      bgColor: Colors.white.withValues(alpha: 0.12),
                      borderColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  if (_isTutorial && _tutorialPhase == 8)
                    _buildInlineBanner(
                      child: Text(
                        '✅ Kliko Zgjidh për $solveCost\$ — zgjidhni fjalën, ruaj lëvizjet!',
                        textAlign: TextAlign.center,
                        style: AppFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      bgColor: Colors.white.withValues(alpha: 0.12),
                      borderColor: Colors.white.withValues(alpha: 0.25),
                    ),
                ],

                // Completion screen (stars + praise + ad offer + action buttons)
                if (_isCompleted)
                  _buildCompletionSection(),

                // Lost screen (empty stars + message + ad continue + replay)
                if (_game.gameLost && !_isCompleted)
                  _buildLostSection(),

                SizedBox(height: bottomPad > 0 ? 8 : 16),
              ],
            ),
          ),

          // Tutorial overlays (blocking modals)
          if (_isTutorial && [1, 3, 4, 6, 7].contains(_tutorialPhase))
            TutorialOverlay(
              phase: _tutorialPhase,
              onNext: () => _setTutorialPhase(_tutorialPhase + 1),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  Inline banner (above buttons in column)
  // ══════════════════════════════════════

  Widget _buildInlineBanner({
    required Widget child,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  // ── Insufficient coins inline banner ──
  Widget _buildInlineInsufficientBanner() {
    final isSolve = _insufficientType == 'solve';
    final cost = _insufficientType == 'hint' ? hintCost : solveCost;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const CoinIcon(size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isSolve
                    ? 'Ju nuk keni $cost monedha · shiko një reklamë dhe zgjidh falas'
                    : 'Ju nuk keni $cost monedha',
                style: AppFonts.quicksand(
                  color: const Color(0xFFBAE0FD),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSolve) ...[
              const SizedBox(width: 8),
              ShikoButton(
                size: ShikoSize.small,
                loading: _loadingAd,
                onTap: _watchAdForFreeSolve,
              ),
            ],
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _openShop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Bli tani',
                  style: AppFonts.nunito(
                    color: const Color(0xFFBAE0FD),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Header (glass top strip)
  // ══════════════════════════════════════

  Widget _buildHeader(CoinService coinService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1F4A).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Back button (glass)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),

          // Level label (true center via Expanded)
          Expanded(
            child: Center(
              child: Text(
                _isTutorial ? 'Tutorial' : 'Niveli ${_prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1}',
                style: AppFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),

          // Right side: coin badge + shop button (gold tinted)
          CoinBadge(
            amount: coinService.coins,
            onTap: () => _openShop(),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _openShop();
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF4B400).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF4B400).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.shopping_cart, color: Color(0xFFFFD86B), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _openShop() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ShopSheet(),
    );
  }

  // ══════════════════════════════════════
  //  Info row: stars | difficulty | moves
  // ══════════════════════════════════════

  Widget _buildInfoRow() {
    final swapsRemaining = _game.swapsRemaining;
    final isWarning = swapsRemaining <= 10 && swapsRemaining > 5;
    final isDanger = swapsRemaining <= 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // Stars preview
          if (!_isTutorial)
            Row(
              children: List.generate(3, (i) {
                final lit = i < _previewStars;
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    Icons.star,
                    size: 15,
                    color: lit ? const Color(0xFFF4B400) : Colors.white.withValues(alpha: 0.18),
                    shadows: lit
                        ? [Shadow(color: const Color(0xFFF4B400).withValues(alpha: 0.7), blurRadius: 4)]
                        : null,
                  ),
                );
              }),
            )
          else
            const SizedBox(width: 48),

          const Spacer(),

          // Difficulty pill
          if (!_isTutorial)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: _difficultyBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _difficultyBorderColor, width: 1.5),
              ),
              child: Text(
                _difficultyLabel.toUpperCase(),
                style: AppFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: _difficultyColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),

          const Spacer(),

          // Moves remaining
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$swapsRemaining',
                style: AppFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDanger
                      ? const Color(0xFFFCA5A5)
                      : isWarning
                          ? const Color(0xFFFCD34D)
                          : Colors.white,
                ),
              ),
              Text(
                'lëvizje të mbetura',
                style: AppFonts.quicksand(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  Loading overlay (splash-style with bg tiles + progress bar)
  // ══════════════════════════════════════

  static const _loadingLetters = 'ABCÇDEHIMNOPRSTUVXZË';
  static const _loadingTileColors = [Color(0xFFF4B400), Color(0xFF22C55E), Color(0xFF787c7e)];

  Widget _buildLoadingOverlay() {
    final size = MediaQuery.of(context).size;
    final rng = Random(42);
    final tiles = <Widget>[];

    // 15 tiles scattered across the full area with random jitter
    const cols = 5;
    const rows = 3;
    final cellW = (size.width - 40) / cols;
    final cellH = (size.height * 0.75) / rows;
    for (int i = 0; i < 15; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = 20 + col * cellW + (rng.nextDouble() - 0.5) * cellW * 0.6;
      final y = size.height * 0.15 + row * cellH + (rng.nextDouble() - 0.5) * cellH * 0.4;
      tiles.add(Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: 0.72,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _loadingTileColors[i % 3],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _loadingLetters[rng.nextInt(_loadingLetters.length)],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ));
    }

    return Stack(
      children: [
        ...tiles,
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              Container(
                width: 180,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4B400),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════
  //  Ad helpers
  // ══════════════════════════════════════

  void _watchAdForFreeSolve() async {
    final adService = context.read<AdService>();
    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.freeSolve,
      onReward: () async {
        _audio.play(Sfx.solve);
        _game.solveWord();
      },
    );

    if (mounted) {
      setState(() {
        _loadingAd = false;
        if (success) _insufficientType = null;
      });
    }
  }

  void _watchAdToDoubleWinCoins() async {
    final adService = context.read<AdService>();
    final coinService = context.read<CoinService>();

    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.doubleWinCoins,
      onReward: () async {
        coinService.add(_coinsEarned);
        _audio.play(Sfx.coin);
      },
    );

    if (mounted) {
      setState(() {
        _loadingAd = false;
        if (success) _winCoinsDoubled = true;
      });
    }
  }

  void _watchAdToContinue() async {
    final adService = context.read<AdService>();

    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.continueAfterLoss,
      onReward: () async {
        _game.continueGame();
        _audio.play(Sfx.coin);
        HapticFeedback.mediumImpact();
      },
    );

    if (mounted) {
      setState(() {
        _loadingAd = false;
        if (success) _continuedAfterLoss = true;
      });
    }
  }

  // ══════════════════════════════════════
  //  Completion section
  // ══════════════════════════════════════

  Widget _buildCompletionSection() {
    final showDoubleAd = !_isTutorial && _coinsEarned > 0 && !_winCoinsDoubled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Stars ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < _completedStars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.star,
                    size: 32,
                    color: filled ? const Color(0xFFF4B400) : Colors.white.withValues(alpha: 0.15),
                    shadows: filled
                        ? [Shadow(color: const Color(0xFFF4B400).withValues(alpha: 0.7), blurRadius: 6)]
                        : [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2)],
                  ),
                );
              }),
            ),

            // ── Win summary row: praise + coins ──
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _completedPraise,
                  style: AppFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4ADE80),
                  ),
                ),
                if (_coinsEarned > 0) ...[
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _winCoinsDoubled ? '+${_coinsEarned * 2}' : '+$_coinsEarned',
                        style: AppFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF4B400),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const CoinIcon(size: 14),
                    ],
                  ),
                ],
              ],
            ),

            // ── Ad offer card: double coins ──
            if (showDoubleAd) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _loadingAd ? null : _watchAdToDoubleWinCoins,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      // Purple icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.purpleAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.35), width: 1.5),
                        ),
                        child: const Icon(Icons.videocam, color: Color(0xFFC084FC), size: 20),
                      ),
                      const SizedBox(width: 10),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dyfisho monedhat',
                              style: AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '+${_coinsEarned > 0 ? _coinsEarned * 2 : 20} monedha falas',
                              style: AppFonts.quicksand(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Watch button with x2 badge
                      ShikoButton(
                        size: ShikoSize.medium,
                        loading: _loadingAd,
                        onTap: _watchAdToDoubleWinCoins,
                        badge: '×2',
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Action buttons row: play again + next level ──
            const SizedBox(height: 8),
            Row(
              children: [
                // Play again (white glass)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _audio.play(Sfx.button);
                      _restartLevel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Luaj përsëri',
                            style: AppFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Next level (purple glass)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _audio.play(Sfx.button);
                      _nextLevel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.purpleAccent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.purpleAccent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isTutorial ? 'Fillo Lojën' : 'Luaj nivelin $_nextLevelNumber',
                            style: AppFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Lost section
  // ══════════════════════════════════════

  Widget _buildLostSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Empty stars ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  Icons.star,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.15),
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2)],
                ),
              )),
            ),

            // ── "Dështove!" ──
            const SizedBox(height: 4),
            Text(
              'Dështove!',
              style: AppFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFCA5A5),
              ),
            ),
            const SizedBox(height: 12),

            // ── Continue with ad (+5 swaps) ──
            if (!_continuedAfterLoss)
              GestureDetector(
                onTap: _loadingAd ? null : _watchAdToContinue,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.purpleAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.35), width: 1.5),
                        ),
                        child: const Icon(Icons.videocam, color: Color(0xFFC084FC), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vazhdo lojën', style: AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900)),
                            Text(
                              '+5 lëvizje ekstra',
                              style: AppFonts.quicksand(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      ShikoButton(
                        size: ShikoSize.medium,
                        loading: _loadingAd,
                        onTap: _watchAdToContinue,
                      ),
                    ],
                  ),
                ),
              ),

            // ── Play again button (white glass) ──
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _audio.play(Sfx.button);
                      _restartLevel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Luaj përsëri',
                            style: AppFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Bottom controls (Solve + Hint)
  // ══════════════════════════════════════

  Widget _buildBottomControls(CoinService coinService) {
    final canAffordHintNow = _isTutorial || coinService.canAfford(hintCost);
    final canAffordSolveNow = _isTutorial || coinService.canAfford(solveCost);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Row(
          children: [
            // Solve button (green glass)
            Expanded(
              child: _controlButton(
                icon: Icons.check_circle_outline,
                label: 'Zgjidh · $solveCost',
                enabled: _game.canSolveWord &&
                    !(_isTutorial && (_tutorialPhase == 2 || _tutorialPhase == 5)),
                cooling: _game.solveWordCooldown,
                cooldownRemaining: _game.solveWordCooldownRemaining,
                pulsing: _isTutorial && _tutorialPhase == 8,
                onTap: _onSolveWord,
                showWatchBadge: !_isTutorial && !canAffordSolveNow,
                isSolve: true,
              ),
            ),
            const SizedBox(width: 10),
            // Hint button (yellow glass)
            Expanded(
              child: _controlButton(
                icon: Icons.lightbulb_outline,
                label: 'Ndihmë · $hintCost',
                enabled: _game.canHint &&
                    !(_isTutorial && (_tutorialPhase == 2 || _tutorialPhase == 8)),
                cooling: _game.hintCooldown,
                cooldownRemaining: _game.hintCooldownRemaining,
                pulsing: _isTutorial && _tutorialPhase == 5,
                onTap: _onHint,
                showWatchBadge: false,
                noCoins: !_isTutorial && !canAffordHintNow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required bool cooling,
    required int cooldownRemaining,
    required bool pulsing,
    required VoidCallback onTap,
    bool showWatchBadge = false,
    bool isSolve = false,
    bool noCoins = false,
  }) {
    final baseColor = isSolve
        ? const Color(0xFF6AAA64)
        : const Color(0xFFC9B458);

    final isDisabled = !enabled && !cooling;
    final effectiveOpacity = noCoins ? 0.55 : 1.0;

    return Opacity(
      opacity: effectiveOpacity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: cooling
                    ? baseColor.withValues(alpha: 0.08)
                    : isDisabled
                        ? Colors.white.withValues(alpha: 0.06)
                        : baseColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cooling
                      ? baseColor.withValues(alpha: 0.2)
                      : isDisabled
                          ? Colors.white.withValues(alpha: 0.1)
                          : baseColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: (enabled && !cooling)
                    ? [BoxShadow(color: baseColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Button content
                  Opacity(
                    opacity: (isDisabled && !cooling) ? 0.28 : (cooling ? 0.4 : 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: AppFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const CoinIcon(size: 11),
                      ],
                    ),
                  ),
                  // Cooldown bar centered below label inside button
                  if (cooling) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 4,
                        color: Colors.black.withValues(alpha: 0.2),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: cooldownRemaining / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: baseColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Watch badge (glass style, top-right)
          if (showWatchBadge)
            Positioned(
              top: -7,
              right: -5,
              child: ShikoButton(size: ShikoSize.small),
            ),
        ],
      ),
    );
  }
}
