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
    final puzzle = puzzleStore.get(level);

    if (puzzle != null) {
      _game.initPuzzle(puzzle, level: level);
      setState(() => _isLoading = false);
    } else {
      // Puzzle not ready — try to generate on-the-fly
      puzzleStore.regenerate(level);
      final retryPuzzle = puzzleStore.get(level);
      if (retryPuzzle != null) {
        _game.initPuzzle(retryPuzzle, level: level);
      }
      setState(() => _isLoading = false);
    }
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
      _coinsEarned = _difficultyCoinMap[Difficulty.easy]!;
      coinService.add(_coinsEarned);
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

  Color get _difficultyColor {
    final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    final d = difficultyForLevel(playingLevel);
    switch (d) {
      case Difficulty.easy:   return AppColors.diffEasy;
      case Difficulty.medium: return AppColors.diffMedium;
      case Difficulty.hard:   return AppColors.diffHard;
      case Difficulty.expert: return AppColors.diffExpert;
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinService = context.watch<CoinService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B40), Color(0xFF142452)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(coinService),
                  if (!_isCompleted && !_game.gameLost && !_isLoading)
                    _buildInfoRow(),
                  const SizedBox(height: 8),

                  // Hint/insufficient coins banner
                  if (_game.hintMessage.isNotEmpty && !_isTutorial && _insufficientType == null)
                    _buildHintBanner(),
                  if (_insufficientType != null)
                    _buildInsufficientBanner(),

                  // Tutorial banner for interactive phases
                  if (_isTutorial && _tutorialPhase == 2)
                    const TutorialBanner(text: '👆 Kliko shkronjat për të bërë 1 lëvizje'),
                  if (_isTutorial && _tutorialPhase == 5)
                    TutorialBanner(text: '💡 Kliko Ndihmën për $hintCost\$ — shkronjat, ruaj lëvizjet!'),
                  if (_isTutorial && _tutorialPhase == 8)
                    TutorialBanner(text: '✅ Kliko Zgjidh për $solveCost\$ — zgjidhni fjalën, ruaj lëvizjet!'),

                  const SizedBox(height: 8),

                  // Game board
                  if (!_isLoading)
                    Expanded(
                      child: Center(
                        child: ListenableBuilder(
                          listenable: _game,
                          builder: (context, _) => GameBoard(
                            game: _game,
                            tutorialHighlight: _tutorialHighlightCells,
                            disableSwap: _isTutorial && (_tutorialPhase == 5 || _tutorialPhase == 8),
                          ),
                        ),
                      ),
                    )
                  else
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.cellGreen),
                      ),
                    ),

                  // Completion screen
                  if (_isCompleted)
                    _buildCompletionSection(),

                  // Lost screen
                  if (_game.gameLost && !_isCompleted)
                    _buildLostSection(),

                  // Bottom controls (hint/solve)
                  if (!_isCompleted && !_game.gameLost && !_isLoading)
                    _buildBottomControls(coinService),

                  const SizedBox(height: 8),
                ],
              ),

              // Tutorial overlays (blocking modals)
              if (_isTutorial && [1, 3, 4, 6, 7].contains(_tutorialPhase))
                TutorialOverlay(
                  phase: _tutorialPhase,
                  onNext: () => _setTutorialPhase(_tutorialPhase + 1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CoinService coinService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white60, size: 18),
            ),
          ),
          const Spacer(),
          CoinBadge(
            amount: coinService.coins,
            onTap: () => _openShop(),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _openShop();
            },
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Icon(Icons.shopping_cart, color: Colors.white60, size: 18),
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

  Widget _buildInfoRow() {
    final swapsRemaining = _game.swapsRemaining;
    final isWarning = swapsRemaining <= 10 && swapsRemaining > 5;
    final isDanger = swapsRemaining <= 5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Stars preview
          if (!_isTutorial)
            Row(
              children: List.generate(3, (i) => Icon(
                Icons.star,
                size: 15,
                color: i < _previewStars ? AppColors.gold : Colors.white12,
              )),
            )
          else
            const SizedBox(width: 45),

          const Spacer(),

          // Difficulty label
          if (!_isTutorial)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _difficultyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _difficultyLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _difficultyColor,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDanger
                      ? AppColors.redAccent
                      : isWarning
                          ? AppColors.yellowAccent
                          : Colors.white,
                ),
              ),
              Text(
                'lëvizje të mbetura',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lightbulb, color: AppColors.gold, size: 15),
          const SizedBox(width: 6),
          Text(
            _game.hintMessage,
            style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientBanner() {
    final isHint = _insufficientType == 'hint';
    final isSolve = _insufficientType == 'solve';
    final cost = isHint ? hintCost : solveCost;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Ju nuk keni $cost monedha',
              style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // Watch ad for free solve
          if (isSolve) ...[
            GestureDetector(
              onTap: _loadingAd ? null : _watchAdForFreeSolve,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_loadingAd)
                      const SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
                      )
                    else
                      const Icon(Icons.play_arrow, color: AppColors.gold, size: 12),
                    const SizedBox(width: 2),
                    const Text('Falas', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
          GestureDetector(
            onTap: _openShop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cellGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Bli tani',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _watchAdForFreeSolve() async {
    final adService = context.read<AdService>();
    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.freeSolve,
      onReward: () async {
        // Perform the solve for free
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

  Widget _buildCompletionSection() {
    final showDoubleAd = !_isTutorial && _coinsEarned > 0 && !_winCoinsDoubled;
    final showPlayAgain = !_isTutorial && _completedStars == 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.star,
                size: 32,
                color: i < _completedStars ? AppColors.gold : Colors.white12,
              ),
            )),
          ),
          const SizedBox(height: 8),

          // Praise + coins
          Text(
            _completedPraise,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          if (_coinsEarned > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _winCoinsDoubled ? '+${_coinsEarned * 2}' : '+$_coinsEarned',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
                if (_winCoinsDoubled) ...[
                  const SizedBox(width: 4),
                  const Text('×2', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),

          // x2 coins ad offer (not in tutorial, only if coins earned and not yet doubled)
          if (showDoubleAd)
            GestureDetector(
              onTap: _loadingAd ? null : _watchAdToDoubleWinCoins,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.white54, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dyfisho monedhat', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            '+${_coinsEarned} monedha ekstra',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('×2', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    if (_loadingAd)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cellGreen),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cellGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white, size: 13),
                            SizedBox(width: 2),
                            Text('Shiko', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Play again for 3 stars prompt
          if (showPlayAgain) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppColors.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Merr 3 yje!', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          'Luaj përsëri për rezultat më të mirë',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _restartLevel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text('Luaj', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              if (!showPlayAgain)
                Expanded(
                  child: _actionButton(
                    icon: Icons.refresh,
                    label: 'Luaj përsëri',
                    color: AppColors.surface,
                    onTap: _restartLevel,
                  ),
                ),
              if (!showPlayAgain)
                const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.arrow_forward_ios,
                  label: _isTutorial ? 'Fillo Lojën' : 'Niveli tjetër',
                  color: AppColors.cellGreen,
                  onTap: _nextLevel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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

  Widget _buildLostSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Empty stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.star, size: 32, color: Colors.white12),
            )),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dështove!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.redAccent),
          ),
          const SizedBox(height: 12),

          // Continue with ad (+5 swaps)
          if (!_continuedAfterLoss)
            GestureDetector(
              onTap: _loadingAd ? null : _watchAdToContinue,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_loadingAd)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                      )
                    else
                      const Icon(Icons.play_arrow, color: AppColors.gold, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Shiko reklamë — +5 lëvizje ekstra',
                      style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          _actionButton(
            icon: Icons.refresh,
            label: 'Luaj përsëri',
            color: AppColors.surface,
            onTap: _restartLevel,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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

  Widget _buildBottomControls(CoinService coinService) {
    final canAffordHint = _isTutorial || coinService.canAfford(hintCost);
    final canAffordSolve = _isTutorial || coinService.canAfford(solveCost);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Solve button
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
              showWatchBadge: !_isTutorial && !canAffordSolve,
            ),
          ),
          const SizedBox(width: 10),
          // Hint button
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
            ),
          ),
        ],
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
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.surface
                  : AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: pulsing
                  ? Border.all(color: AppColors.gold, width: 2)
                  : Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Stack(
              children: [
                // Cooldown bar
                if (cooling)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      child: LinearProgressIndicator(
                        value: cooldownRemaining / 3,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.1)),
                        minHeight: 4,
                      ),
                    ),
                  ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: enabled ? Colors.white : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.monetization_on, color: Colors.white.withValues(alpha: 0.5), size: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showWatchBadge)
          Positioned(
            top: -8, right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cellGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '▶ Shiko',
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
