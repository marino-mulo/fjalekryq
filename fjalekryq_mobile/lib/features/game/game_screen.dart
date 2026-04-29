import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/puzzle.dart';
import '../../core/models/level_config.dart';
import '../../core/services/game_service.dart';
import '../../core/services/audio_service.dart';
import '../../shared/widgets/animated_icon_fx.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/level_puzzle_store.dart';
import '../../core/database/repositories/game_state_repository.dart';
import '../../core/database/repositories/progress_repository.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_loading_view.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/offline_view.dart';
import '../tutorial/tutorial_finger.dart';
import 'widgets/game_board.dart';
import 'widgets/win_modal.dart';
import 'widgets/fail_modal.dart';
import 'widgets/save_progress_prompt_modal.dart';

const _levelKey = 'fjalekryq_level';
const _playingLevelKey = 'fjalekryq_playing_level';
const _tutorialKey = 'fjalekryq_tutorial_done';

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
  // 0 = off, 1 = swap (interactive on highlighted cells),
  // 2 = hint (Ndihmë button), 3 = solve (Zgjidh button).
  // No modals — every step is a banner + animated finger.
  int _tutorialPhase = 0;
  List<({int row, int col})> _tutorialHighlightCells = [];

  // Completion state
  bool _isCompleted = false;
  String _completedPraise = 'Bravo!';

  // Loading state
  bool _isLoading = false;

  // Ad state
  bool _loadingAd = false;
  bool _continuedAfterLoss = false;

  // Stored so we can call disposeBanner() safely in dispose()
  late AdService _adServiceRef;

  // 5-moves warning (shown once per game session)
  bool _fiveMovesWarningShown = false;
  bool _showFiveMovesBanner = false;
  // Snapshot of move / hint counters captured when the five-moves banner
  // first appears, so we can auto-dismiss it as soon as the player makes
  // progress (a swap or a hint) instead of forcing them to close it.
  int _fiveMovesSnapshotSwaps = 0;
  int _fiveMovesSnapshotHints = 0;
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

    _adServiceRef = context.read<AdService>();
    // Skip ad loads when this launch will land on the tutorial — first-run
    // players shouldn't see ads before they've completed a real level.
    final willBeTutorial = ((_prefs.getInt(_levelKey) ?? 1) == 1 &&
            !(_prefs.getBool(_tutorialKey) ?? false)) ||
        (_prefs.getBool('fjalekryq_force_tutorial') ?? false);
    if (!willBeTutorial) {
      _adServiceRef.loadBanner();
      _adServiceRef.preloadInterstitial();
    }

    _initializeGame();
  }

  @override
  void dispose() {
    _adServiceRef.disposeBanner();
    _game.removeListener(_onGameChanged);
    _game.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (!mounted) return;

    // Auto-advance tutorial phases. Each step is a banner with a pointing
    // finger; we move forward as soon as the player performs the action
    // the banner describes. Phase 3 → finish ends the tutorial directly,
    // no completion modal.
    if (_isTutorial) {
      if (_tutorialPhase == 1 && _game.totalSwapCount > 0) {
        _setTutorialPhase(3);
      } else if (_tutorialPhase == 3 && _game.solveWordCooldown) {
        Future.microtask(() {
          if (mounted && _isTutorial) _finishTutorial();
        });
      }
    }

    // 5-moves warning: offer more moves before it's too late
    if (!_isTutorial &&
        !_fiveMovesWarningShown &&
        !_game.gameLost &&
        !_game.gameWon &&
        _game.swapsRemaining == 5) {
      _fiveMovesWarningShown = true;
      Future.microtask(() {
        if (mounted) _showFiveMovesOffer();
      });
    }

    // Auto-dismiss the 5-moves banner as soon as the player acts —
    // swapping a tile or taking a hint counts as "moved on", so the
    // banner shouldn't keep hovering after the decision is made.
    if (_showFiveMovesBanner &&
        (_game.totalSwapCount != _fiveMovesSnapshotSwaps ||
         _game.hintCount      != _fiveMovesSnapshotHints)) {
      Future.microtask(() {
        if (mounted && _showFiveMovesBanner) {
          setState(() => _showFiveMovesBanner = false);
        }
      });
    }

    // Auto-trigger win modal (skip if we're loading or in tutorial — the
    // tutorial "completed" overlay handles its own ending).
    if (_game.gameWon && !_isCompleted && !_isLoading && !_isTutorial) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_isLoading) _onWin();
      });
    }

    // Auto-process the fail event once (sfx + counter). The fail panel is
    // rendered inline below the puzzle in build() whenever _game.gameLost.
    // Suppressed in tutorial so the training session always ends on
    // the completion overlay.
    if (_game.gameLost && !_isCompleted && !_showingFailModal && !_isTutorial) {
      _showingFailModal = true;
      _failCount++;
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
    _continuedAfterLoss = false;
    _loadingAd = false;
    _fiveMovesWarningShown = false;
    _showingFailModal = false;
    _failCount = 0;
    _game.clearSavedState();
    // Mark level as in-progress so home screen shows "Continue"
    final lvl = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
    _prefs.setBool('fjalekryq_in_progress_$lvl', true);

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

  /// Finish the tutorial after the player completes phase 9 (the final
  /// "Tutorial completed" modal). Marks the pref so the tutorial never
  /// auto-runs again and returns the player to home.
  void _finishTutorial() {
    _prefs.setBool(_tutorialKey, true);
    setState(() {
      _isTutorial = false;
      _tutorialPhase = 0;
      _tutorialHighlightCells = [];
    });
    _game.setTutorialMode(false);
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  void _setTutorialPhase(int phase) {
    setState(() {
      _tutorialPhase = phase;
      // Only the swap step highlights cells — hint/solve point at the
      // bottom-row buttons instead, so the board stays unhighlighted.
      if (phase == 1) {
        _tutorialHighlightCells = [(row: 0, col: 3), (row: 1, col: 0)];
      } else {
        _tutorialHighlightCells = [];
      }
    });
  }

  void _onWin() {
    if (_isCompleted) return;
    HapticFeedback.heavyImpact();
    _audio.play(Sfx.win);
    _tutorialPhase = 0;
    _tutorialHighlightCells = [];
    _isCompleted = true;
    _completedPraise = _praises[DateTime.now().millisecond % _praises.length];

    if (!_isTutorial) {
      final playingLevel = _prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1;
      final progress = _prefs.getInt(_levelKey) ?? 1;
      final movesLeft = _game.swapsRemaining;

      _prefs.remove('fjalekryq_in_progress_$playingLevel');

      _game.saveProgress(playingLevel, completed: true, movesLeft: movesLeft);

      final isFirstClear = playingLevel >= progress;
      if (isFirstClear) {
        _prefs.setInt(_levelKey, playingLevel + 1);
      }
    }
    setState(() {});

    // Show animated win modal after a brief celebration pause
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _showWinModal();
    });
  }

  void _onHint() async {
    HapticFeedback.mediumImpact();
    _audio.play(Sfx.hint);
    _game.hint();
  }

  void _onSolveWord() {
    HapticFeedback.mediumImpact();
    _audio.play(Sfx.solve);
    _game.solveWord();
  }

  void _nextLevel() async {
    if (_isTutorial) {
      _prefs.setBool(_tutorialKey, true);
      _isTutorial = false;
      _tutorialPhase = 0;
      _tutorialHighlightCells = [];
      _game.setTutorialMode(false);
      _loadPuzzle();
    } else {
      final adService = context.read<AdService>();
      await adService.showInterstitialIfDue();
      if (!mounted) return;
      final progress = _prefs.getInt(_levelKey) ?? 1;
      _prefs.setInt(_playingLevelKey, progress);
      _loadPuzzle();
    }
  }

  void _restartLevel() {
    setState(() {
      _isCompleted = false;
      _continuedAfterLoss = false;
      _loadingAd = false;
      _fiveMovesWarningShown = false;
      _showFiveMovesBanner = false;
      _showingFailModal = false;
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
        children: [
          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
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
                      disableSwap: _isTutorial && (_tutorialPhase == 2 || _tutorialPhase == 3),
                    ),
                  )
                else
                  Expanded(child: _buildLoadingOverlay()),

                // Inline fail panel — shown below the puzzle on loss.
                if (_game.gameLost && !_isCompleted && !_isLoading)
                  InlineFailPanel(
                    adService: context.read<AdService>(),
                    onWatchAd: _watchAdToContinue,
                    onRestart: () {
                      setState(() => _showingFailModal = false);
                      _restartLevel();
                    },
                  ),

                // Bottom controls (solve/hint) — only during active play
                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  const SizedBox(height: 12),

                if (!_isCompleted && !_game.gameLost && !_isLoading)
                  _buildBottomControls(),

                // Banners (hints / tutorial tips)
                if (!_isCompleted && !_game.gameLost && !_isLoading) ...[
                  const SizedBox(height: 8),
                  if (_game.hintMessage.isNotEmpty && !_isTutorial)
                    _buildInlineBanner(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AnimatedIconFx(
                            Icons.lightbulb_outline,
                            style: IconFxStyle.pulse,
                            color: Color(0xFFFFD86B),
                            size: 15,
                          ),
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
                  if (_isTutorial && _tutorialPhase == 1)
                    _buildTutorialInstruction(
                      'Shkëmbe shkronjat e shënuara për të bërë 1 lëvizje',
                    ),
                  if (_isTutorial && _tutorialPhase == 3)
                    _buildTutorialInstruction(
                      'Kliko butonin Zgjidh — zgjidh një fjalë të plotë',
                    ),
                ],

                // Spacer claims remaining vertical space so the control
                // cluster stays in place regardless of board size. Skipped
                // while the loading overlay uses Expanded() already.
                if (!_isLoading) const Spacer(),

                // Reserve bottom space so the floating banner ad doesn't
                // cover the control cluster. Height matches the live ad
                // size and collapses to zero when no ad is ready.
                Consumer<AdService>(
                  builder: (_, ads, __) => SizedBox(
                    height: (!_isTutorial && ads.bannerReady)
                        ? ads.bannerAd!.size.height.toDouble() + 16
                        : 0,
                  ),
                ),
              ],
            ),
          ),

          // Floating banner ad — sticks to the bottom of the puzzle page
          // with a soft shadow + rounded pill so it reads as a chip, not
          // as a layout component. Overlays content without reserving a
          // separate scaffold slot.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Consumer<AdService>(
              builder: (_, ads, __) {
                // No ads in the tutorial — keeps the first-run flow clean
                // and avoids teaching ad placement before the game itself.
                if (_isTutorial || !ads.bannerReady) {
                  return const SizedBox.shrink();
                }
                final adW = ads.bannerAd!.size.width.toDouble();
                final adH = ads.bannerAd!.size.height.toDouble();
                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Center(
                      child: Container(
                        width: adW,
                        height: adH,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AdWidget(ad: ads.bannerAd!),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Inline banner (above buttons in column)
  // ══════════════════════════════════════

  /// Tutorial banner — text only. The pointing finger lives on the board
  /// (highlighted cells during the swap step) or above the bottom-row
  /// buttons (Ndihmë / Zgjidh steps), never inside the banner itself.
  Widget _buildTutorialInstruction(String text) {
    return _buildInlineBanner(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppFonts.quicksand(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
      bgColor: AppColors.gold.withValues(alpha: 0.14),
      borderColor: AppColors.gold.withValues(alpha: 0.4),
    );
  }

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
  //
  // Shares the exact visual recipe as the fail-screen revive banner and
  // the win-screen ×2-coins banner: purple-accent pill, bolt icon, white
  // label, and a single pill badge on the right. The badge swaps between
  // "pay 30 coins" when the player can afford and "watch an ad" otherwise.
  Widget _buildFiveMovesBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: () async {
          if (_loadingAd) return;
          setState(() => _showFiveMovesBanner = false);
          await _watchAdForExtraMoves();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.purpleAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.purpleAccent.withValues(alpha: 0.38),
            ),
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
              const Icon(Icons.videocam_rounded,
                  color: Color(0xFFC084FC), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vetëm 5 lëvizje të mbetura!',
                  style: AppFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE9D5FF),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.purpleAccent.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.purpleAccent.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                'Shiko · +5',
                style: AppFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE9D5FF),
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Insufficient coins inline banner ──
  // ══════════════════════════════════════
  //  Header (glass top strip)
  // ══════════════════════════════════════

  Widget _buildHeader() {
    final levelLabel = _isTutorial
        ? 'SI TË LUASH'
        : 'NIVELI \${_prefs.getInt(_playingLevelKey) ?? _prefs.getInt(_levelKey) ?? 1}';
    return AppTopBar(title: levelLabel);
  }

  // ══════════════════════════════════════
  //  Info row: difficulty | moves
  // ══════════════════════════════════════

  Widget _buildInfoRow() {
    final swapsRemaining = _game.swapsRemaining;
    final isWarning = swapsRemaining <= 10 && swapsRemaining > 5;
    final isDanger  = swapsRemaining <= 5;

    final Color color = isDanger
        ? const Color(0xFFFCA5A5)
        : isWarning
            ? const Color(0xFFFCD34D)
            : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        // Full-row, centered: "<n> lëvizje të mbetura" on a single line
        // so the moves counter reads as a clear, balanced status line
        // rather than a small block tucked to the right.
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$swapsRemaining ',
            style: AppFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            'lëvizje të mbetura',
            style: AppFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
    );
  }

  // ══════════════════════════════════════
  //  Loading overlay — AppBackground shows through from the parent
  // ══════════════════════════════════════

  Widget _buildLoadingOverlay() {
    return const AppLoadingIndicator();
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

    if (mounted) setState(() => _loadingAd = false);
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

  // ── 5-moves warning banner ───────────────────────────────
  void _showFiveMovesOffer() {
    setState(() {
      _showFiveMovesBanner = true;
      _fiveMovesSnapshotSwaps = _game.totalSwapCount;
      _fiveMovesSnapshotHints = _game.hintCount;
    });
  }

  // ── Win modal ────────────────────────────────────────────
  void _showWinModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, // win screen provides its own background
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, _, __) => WinModal(
        praise: _completedPraise,
        isTutorial: _isTutorial,
        nextLevelNumber: _nextLevelNumber,
        solvedGrid: _game.solution,
        onNextLevel: () {
          setState(() {
            _isCompleted = false;
            _isLoading = true;
          });
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _nextLevel();
          });
        },
        onGoHome: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
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
      transitionBuilder: (ctx, anim, _, child) {
        // Instant dismiss so the loading spinner isn't revealed through a
        // lingering animation — entrance slides up from the bottom edge.
        if (anim.status == AnimationStatus.reverse ||
            anim.status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
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
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              await _prefs.setString('fjalekryq_account_type', 'google');
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

  Widget _buildBottomControls() {
    final pointSolve = _isTutorial && _tutorialPhase == 3;

    Widget withFinger({required bool show, required Widget child}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            child: show
                ? const TutorialFinger(
                    direction: FingerDirection.down, size: 24)
                : null,
          ),
          child,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: withFinger(
                show: pointSolve,
                child: _controlButton(
                  icon: Icons.lightbulb_outline,
                  label: 'Zgjidh',
                  enabled: _game.canSolveWord &&
                      !(_isTutorial && _tutorialPhase == 1),
                  cooling: _game.solveWordCooldown,
                  cooldownRemaining: _game.solveWordCooldownRemaining,
                  pulsing: _isTutorial && _tutorialPhase == 3,
                  onTap: _onSolveWord,
                  isSolve: true,
                ),
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
    bool isSolve = false,
  }) {
    final baseColor = isSolve
        ? const Color(0xFF6AAA64)
        : const Color(0xFFC9B458);

    final isDisabled = !enabled && !cooling;

    return Stack(
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

        ],
      ),
    );
  }
}
