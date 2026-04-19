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
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/coin_badge.dart';
import '../../shared/widgets/offline_view.dart';
import '../../shared/widgets/shiko_button.dart';
import '../tutorial/tutorial_overlay.dart';
import '../shop/shop_screen.dart';
import 'widgets/game_board.dart';
import 'widgets/win_modal.dart';
import 'widgets/fail_modal.dart';
import 'widgets/save_progress_prompt_modal.dart';

const _levelKey = 'fjalekryq_level';
const _playingLevelKey = 'fjalekryq_playing_level';
const _tutorialKey = 'fjalekryq_tutorial_done';
const _starsKeyPrefix = 'fjalekryq_stars_';
const _replayRunKeyPrefix = 'fjalekryq_replay_run_';

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

  // Replay mode: true when user restarts after already getting 3 stars.
  // In this mode no progress is saved, no rewards are shown, 5-moves warning is skipped.
  bool _isReplayRun = false;

  // 5-moves warning (shown once per game session)
  bool _fiveMovesWarningShown = false;
  bool _showFiveMovesBanner = false;
  // Prevents double fail-modal triggers
  bool _showingFailModal = false;
  // Counts fails on the same level — unlocks Special Offer after 2+
  int _failCount = 0;

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

    // 5-moves warning: offer more moves before it's too late (skip in replay runs)
    if (!_isTutorial &&
        !_isReplayRun &&
        !_fiveMovesWarningShown &&
        !_game.gameLost &&
        !_game.gameWon &&
        _game.swapsRemaining == 5) {
      _fiveMovesWarningShown = true;
      Future.microtask(() {
        if (mounted) _showFiveMovesOffer();
      });
    }

    // Auto-trigger win modal (skip if we're loading a new puzzle)
    if (_game.gameWon && !_isCompleted && !_isLoading) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_isLoading) _onWin();
      });
    }

    // Auto-trigger fail modal (once)
    if (_game.gameLost && !_isCompleted && !_showingFailModal) {
      _showingFailModal = true;
      _failCount++;
      _audio.play(Sfx.lose);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _showFailModal();
      });
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
        _isReplayRun = _prefs.getBool('$_replayRunKeyPrefix$playingLevel') ?? false;
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
    _fiveMovesWarningShown = false;
    _showingFailModal = false;
    _failCount = 0;
    _game.clearSavedState();

    final level = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    final puzzleStore = context.read<LevelPuzzleStore>();

    puzzleStore.generate(level).then((puzzle) {
      if (!mounted) return;
      if (puzzle != null) {
        // Apply bonus swaps for "easy-win" levels (1 and 5)
        final bonus = extraSwapsForLevel(level);
        final finalPuzzle = bonus > 0
            ? Wordle7Puzzle(
                gridSize: puzzle.gridSize,
                solution: puzzle.solution,
                words: puzzle.words,
                swapLimit: puzzle.swapLimit + bonus,
                hash: puzzle.hash,
              )
            : puzzle;
        _game.initPuzzle(finalPuzzle, level: level);
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

      // Always save best stars (replay or first clear)
      final starsKey = '$_starsKeyPrefix$playingLevel';
      final existing = _prefs.getInt(starsKey) ?? 0;
      final bestStars = stars > existing ? stars : existing;
      _prefs.setInt(starsKey, bestStars);
      _game.saveProgress(playingLevel, stars: bestStars, completed: true);

      // Clear in-progress and replay flags
      _prefs.remove('fjalekryq_in_progress_$playingLevel');
      _prefs.remove('$_replayRunKeyPrefix$playingLevel');

      // Award coins only on first clear
      final isFirstClear = !_isReplayRun && playingLevel >= progress;
      if (isFirstClear) {
        final diff = difficultyForLevel(playingLevel);
        _coinsEarned = _difficultyCoinMap[diff] ?? 10;
        coinService.add(_coinsEarned);
        Future.delayed(const Duration(milliseconds: 800), () => _audio.play(Sfx.coin));
      } else {
        _coinsEarned = 0;
      }

      // Advance progress on first clear
      if (isFirstClear && playingLevel < totalActiveLevels) {
        _prefs.setInt(_levelKey, playingLevel + 1);
      }
    }
    setState(() {});

    // Show animated win modal after a brief celebration pause
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _showWinModal();
    });
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
    final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    if (!_isTutorial) {
      // Mark as replay so we don't re-award coins — best stars already saved on win.
      _prefs.setBool('$_replayRunKeyPrefix$playingLevel', true);
    }
    setState(() {
      _isCompleted = false;
      _winCoinsDoubled = false;
      _continuedAfterLoss = false;
      _loadingAd = false;
      _fiveMovesWarningShown = false;
      _showFiveMovesBanner = false;
      _showingFailModal = false;
      _isReplayRun = true;
    });
    _game.resetPuzzle();
  }

  // ignore: unused_element
  String get _difficultyLabel {
    final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    return difficultyLabel(difficultyForLevel(playingLevel));
  }

  Difficulty get _difficulty {
    final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    return difficultyForLevel(playingLevel);
  }

  // ignore: unused_element
  Color get _difficultyColor {
    switch (_difficulty) {
      case Difficulty.easy:   return const Color(0xFF4ADE80);
      case Difficulty.medium: return const Color(0xFFFCD34D);
      case Difficulty.hard:   return const Color(0xFFFCA5A5);
      case Difficulty.expert: return const Color(0xFFE879F9);
    }
  }

  // ignore: unused_element
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

  // ignore: unused_element
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
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
        children: [
          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(coinService),
                // Extra breathing room below the header so the board and
                // info row sit lower on the screen (header stays in place).
                const SizedBox(height: 40),
                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  _buildInfoRow(),

                const SizedBox(height: 20),

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

                // Bottom controls (solve/hint) — only during active play
                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  const SizedBox(height: 12),

                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  _buildBottomControls(coinService),

                // Banners (hints / insufficient coins / tutorial tips)
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
                  if (_showFiveMovesBanner)
                    _buildFiveMovesBanner(),
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

  // ── Five-moves warning inline banner ──
  Widget _buildFiveMovesBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFB923C), size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Vetëm 5 lëvizje të mbetura!',
                    style: AppFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFB923C),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showFiveMovesBanner = false),
                  child: const Icon(Icons.close, color: Colors.white38, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _loadingAd ? null : () async {
                      setState(() => _showFiveMovesBanner = false);
                      await _watchAdForExtraMoves();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.purpleAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_rounded, color: Color(0xFFC084FC), size: 15),
                          const SizedBox(width: 5),
                          Text('Shiko · +5', style: AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showFiveMovesBanner = false);
                      _buyExtraMovesInGame();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CoinIcon(size: 13),
                          const SizedBox(width: 5),
                          Text('30 monedha', style: AppFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final levelLabel = _isTutorial
        ? 'TUTORIAL'
        : 'NIVELI ${_prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1}';
    return AppTopBar(
      title: levelLabel,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopScreen(specialOffer: _failCount >= 2),
      ),
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
  //  Loading overlay — AppBackground shows through from the parent
  // ══════════════════════════════════════

  Widget _buildLoadingOverlay() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFF4B400),
      ),
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
      onOffline: () {
        if (mounted) showOfflineSnack(context);
      },
    );

    if (mounted) {
      setState(() {
        _loadingAd = false;
        if (success) _insufficientType = null;
      });
    }
  }

  Future<void> _watchAdToDoubleWinCoins() async {
    final adService = context.read<AdService>();
    final coinService = context.read<CoinService>();

    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.doubleWinCoins,
      onReward: () async {
        coinService.add(_coinsEarned);
        _audio.play(Sfx.coin);
      },
      onOffline: () {
        if (mounted) showOfflineSnack(context);
      },
    );

    if (mounted) {
      setState(() {
        _loadingAd = false;
        if (success) _winCoinsDoubled = true;
      });
    }
  }

  Future<void> _watchAdToContinue() async {
    final adService = context.read<AdService>();

    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.continueAfterLoss,
      onReward: () async {
        _game.continueGame();
        _audio.play(Sfx.coin);
        HapticFeedback.mediumImpact();
      },
      onOffline: () {
        if (mounted) showOfflineSnack(context);
      },
    );

    if (mounted) {
      setState(() {
        _loadingAd = false;
        if (success) {
          _continuedAfterLoss = true;
          _showingFailModal = false;
        }
      });
    }
  }

  // ── Ad: extra moves mid-game (5-moves warning) ──────────
  Future<void> _watchAdForExtraMoves() async {
    final adService = context.read<AdService>();
    setState(() => _loadingAd = true);
    await adService.showRewardedAd(
      adType: AdType.continueAfterLoss,
      onReward: () async {
        _game.addExtraMoves(5);
        _audio.play(Sfx.coin);
        HapticFeedback.mediumImpact();
      },
      onOffline: () {
        if (mounted) showOfflineSnack(context);
      },
    );
    if (mounted) setState(() => _loadingAd = false);
  }

  // ── Coins: buy 5 extra moves mid-game ───────────────────
  void _buyExtraMovesInGame() {
    final coinService = context.read<CoinService>();
    if (!coinService.canAfford(30)) {
      HapticFeedback.heavyImpact();
      _audio.play(Sfx.error);
      _openShop();
      return;
    }
    coinService.spend(30);
    _game.addExtraMoves(5);
    _audio.play(Sfx.coin);
    HapticFeedback.mediumImpact();
  }

  // ── Coins: buy 5 moves after loss ───────────────────────
  void _buyMovesAfterFail() {
    final coinService = context.read<CoinService>();
    if (!coinService.canAfford(30)) {
      HapticFeedback.heavyImpact();
      _audio.play(Sfx.error);
      _openShop();
      return;
    }
    coinService.spend(30);
    _game.continueGame();
    _audio.play(Sfx.coin);
    HapticFeedback.mediumImpact();
    setState(() {
      _continuedAfterLoss = true;
      _showingFailModal = false;
    });
  }

  // ── 5-moves warning banner ───────────────────────────────
  void _showFiveMovesOffer() {
    setState(() => _showFiveMovesBanner = true);
  }

  // ── Win modal ────────────────────────────────────────────
  void _showWinModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.center,
        child: WinModal(
          stars: _completedStars,
          praise: _completedPraise,
          coinsEarned: _coinsEarned,
          winCoinsDoubled: _winCoinsDoubled,
          isTutorial: _isTutorial,
          isReplayRun: _isReplayRun,
          nextLevelNumber: _nextLevelNumber,
          onDoubleCoins: () async {
            await _watchAdToDoubleWinCoins();
          },
          onRestart: () {
            Navigator.pop(ctx);
            Future.microtask(_restartLevel);
          },
          onNextLevel: () {
            // Paint the loading state first so the frame behind the
            // modal is already "loading" — then pop the modal with a
            // zero reverse-transition so it disappears instantly.
            setState(() {
              _isCompleted = false;
              _isLoading = true;
            });
            Navigator.pop(ctx);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _nextLevel();
            });
          },
          onSaveProgress: _shouldShowSavePrompt()
              ? () {
                  Navigator.pop(ctx);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) _showSaveProgressDialog();
                  });
                }
              : null,
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        // When the modal is dismissing, hide it instantly so the loading
        // overlay underneath isn't fading under a lingering modal.
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) {
            if (anim.status == AnimationStatus.reverse ||
                anim.status == AnimationStatus.dismissed) {
              return const SizedBox.shrink();
            }
            return ScaleTransition(
              scale: Tween(begin: 0.72, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child,
              ),
            );
          },
        );
      },
    );
  }

  // ── Fail modal ───────────────────────────────────────────
  void _showFailModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.center,
        child: FailModal(
          adService: context.read<AdService>(),
          coinService: context.read<CoinService>(),
          onWatchAd: () async {
            Navigator.pop(ctx);
            await _watchAdToContinue();
          },
          onBuyMoves: () {
            Navigator.pop(ctx);
            _buyMovesAfterFail();
          },
          onRestart: () {
            Navigator.pop(ctx);
            setState(() => _showingFailModal = false);
            _restartLevel();
          },
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ── Save-progress prompt (guest → Google) ───────────────
  bool _shouldShowSavePrompt() {
    final isGuest = (_prefs.getString('fjalekryq_account_type') ?? '') == 'guest';
    final promptShown = _prefs.getBool('fjalekryq_save_prompt_shown') ?? false;
    final level = _prefs.getInt(_levelKey) ?? 1;
    return isGuest && !promptShown && level >= 6; // after 5+ levels
  }

  void _showSaveProgressDialog() {
    _prefs.setBool('fjalekryq_save_prompt_shown', true);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.center,
        child: SaveProgressPromptModal(
          onSaveWithGoogle: () async {
            Navigator.pop(ctx);
            final coinService = context.read<CoinService>();
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              await _prefs.setString('fjalekryq_account_type', 'google');
              coinService.add(100);
            }
          },
          onDismiss: () => Navigator.pop(ctx),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: anim, child: child),
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
            // Solve button (green glass) — in tutorial the cost is hidden so
            // the player isn't nudged to spend coins they don't track yet.
            Expanded(
              child: _controlButton(
                icon: Icons.check_circle_outline,
                label: _isTutorial ? 'Zgjidh' : 'Zgjidh · $solveCost',
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
            // Hint button (yellow glass) — cost hidden during tutorial.
            Expanded(
              child: _controlButton(
                icon: Icons.lightbulb_outline,
                label: _isTutorial ? 'Ndihmë' : 'Ndihmë · $hintCost',
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
                  // Cooldown bar — animates smoothly as the timer ticks
                  if (cooling) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 4,
                        color: Colors.black.withValues(alpha: 0.2),
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: cooldownRemaining / 3),
                          duration: const Duration(milliseconds: 950),
                          curve: Curves.easeOut,
                          builder: (_, value, __) => FractionallySizedBox(
                            widthFactor: value.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: baseColor.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
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
