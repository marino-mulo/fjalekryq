import 'dart:convert';
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
import '../../core/services/daily_puzzle_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/database/repositories/game_state_repository.dart';
import '../../core/database/repositories/progress_repository.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/offline_view.dart';
import '../../shared/widgets/coin_badge.dart';
import '../../shared/widgets/shiko_button.dart';
import '../shop/shop_screen.dart';
import '../game/widgets/game_board.dart';


const _praises = ['Bravo!', 'Te lumte!', 'Shkelqyeshem!', 'Fantastike!', 'Mahnitese!'];

/// Albanian month names for the date display.
const _months = [
  '', 'Janar', 'Shkurt', 'Mars', 'Prill', 'Maj', 'Qershor',
  'Korrik', 'Gusht', 'Shtator', 'Tetor', 'Nentor', 'Dhjetor',
];

class DailyGameScreen extends StatefulWidget {
  const DailyGameScreen({super.key});

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen> {
  late GameService _game;
  late SharedPreferences _prefs;
  late AudioService _audio;
  late DailyPuzzleService _dailyService;
  late int _userId;

  // Completion state
  bool _isCompleted = false;
  String _completedPraise = 'Bravo!';
  int _coinsEarned = 0;

  // Loading state
  bool _isLoading = true;

  // Already solved today
  bool _alreadySolvedToday = false;

  // Offline: the daily puzzle comes from the server, so if there's no
  // network and no cached puzzle we render an offline placeholder instead
  // of an empty board.
  bool _isOffline = false;

  // Insufficient coins banner
  String? _insufficientType; // 'hint' | 'solve' | null

  // Ad state
  bool _loadingAd = false;
  bool _loadingRestartAd = false;


  // Fail / continue tracking
  bool _failedToday = false;
  Wordle7Puzzle? _todayPuzzle;

  String get _todayDateStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  String get _failKey => 'fjalekryq_daily_failed_$_todayDateStr';

  @override
  void initState() {
    super.initState();
    _prefs = context.read<SharedPreferences>();
    _audio = context.read<AudioService>();
    _userId = context.read<int>();
    _dailyService = context.read<DailyPuzzleService>();
    final gameStateRepo = context.read<GameStateRepository>();
    final progressRepo = context.read<ProgressRepository>();
    _game = GameService(_prefs, gameStateRepo, progressRepo, _userId);
    _game.addListener(_onGameChanged);

    _initializeDaily();
  }

  @override
  void dispose() {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (!mounted) return;

    // Auto-trigger win
    if (_game.gameWon && !_isCompleted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _onWin();
      });
    }

    // Detect loss — save fail state to SharedPrefs for next session
    if (_game.gameLost && !_isCompleted && !_failedToday) {
      _audio.play(Sfx.lose);
      _failedToday = true;
      _prefs.setBool(_failKey, true);
    }

    // Save grid state after every change (for resume)
    if (!_game.gameWon && !_isCompleted && !_isLoading) {
      _dailyService.saveGridState(
        _game.grid,
        _game.swapCount,
        _game.hintCount,
        _game.totalSwapCount,
      );
    }

    setState(() {});
  }

  void _initializeDaily() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    // Ensure daily service is loaded
    if (!_dailyService.isLoaded) {
      await _dailyService.init();
    }

    // Check if already solved today
    if (_dailyService.isTodaySolved) {
      setState(() {
        _alreadySolvedToday = true;
        _isLoading = false;
      });
      return;
    }

    // Load fail state for today
    _failedToday = _prefs.getBool(_failKey) ?? false;

    // Try to resume from saved state
    final saved = await _dailyService.getSavedState();
    final puzzle = await _dailyService.getTodayPuzzle();
    _todayPuzzle = puzzle;

    // No puzzle available — either the server hasn't generated one yet or
    // we can't reach it. Check connectivity to give a clear offline message
    // instead of an empty board.
    if (puzzle == null) {
      final online = await ConnectivityService.hasInternet();
      if (mounted && !online) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
        return;
      }
    }

    if (saved != null &&
        saved.gridJson != null &&
        saved.gridJson!.isNotEmpty &&
        saved.solved != 1) {
      // Resume: load the puzzle and the saved grid
      if (puzzle != null && mounted) {
        try {
          final gridData = jsonDecode(saved.gridJson!) as List;
          final grid = gridData
              .map((r) => (r as List).map((c) => c as String).toList())
              .toList();
          _game.restorePuzzle(
            puzzle,
            grid,
            saved.swapsUsed,
            saved.hintCount,
            saved.totalSwapCount,
          );
        } catch (_) {
          // Corrupted grid — start fresh
          _game.initPuzzle(puzzle);
        }
      }
    } else {
      // Fresh daily puzzle
      if (puzzle != null && mounted) {
        _game.initPuzzle(puzzle);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onWin() async {
    if (_isCompleted) return;
    HapticFeedback.heavyImpact();
    _audio.play(Sfx.win);

    _isCompleted = true;
    _completedPraise = _praises[DateTime.now().millisecond % _praises.length];
    // Daily puzzle awards no coins — only the streak is updated.
    _coinsEarned = 0;

    // Wait for markSolved to update currentStreak before rebuilding so the
    // completion view shows the correct (already-incremented) streak value.
    await _dailyService.markSolved();

    if (!mounted) return;
    setState(() {});
  }

  void _onHint() {
    HapticFeedback.mediumImpact();
    final coinService = context.read<CoinService>();
    if (!coinService.canAfford(hintCost)) {
      HapticFeedback.heavyImpact();
      _audio.play(Sfx.error);
      _showInsufficientCoins('hint');
      return;
    }
    coinService.spend(hintCost);
    _audio.play(Sfx.hint);
    _game.hint();
  }

  void _onSolveWord() {
    HapticFeedback.mediumImpact();
    final coinService = context.read<CoinService>();
    if (!coinService.canAfford(solveCost)) {
      HapticFeedback.heavyImpact();
      _audio.play(Sfx.error);
      _showInsufficientCoins('solve');
      return;
    }
    coinService.spend(solveCost);
    _audio.play(Sfx.solve);
    _game.solveWord();
  }

  void _showInsufficientCoins(String type) {
    setState(() => _insufficientType = type);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _insufficientType = null);
    });
  }

  String get _todayDateLabel {
    final now = DateTime.now();
    return '${now.day} ${_months[now.month]} ${now.year}';
  }

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

  void _watchAdToRestart() async {
    if (_todayPuzzle == null) return;
    final adService = context.read<AdService>();

    setState(() => _loadingRestartAd = true);

    await adService.showRewardedAd(
      adType: AdType.continueAfterLoss,
      onReward: () async {
        _game.initPuzzle(_todayPuzzle!);
        _audio.play(Sfx.coin);
        HapticFeedback.mediumImpact();
        // Reset fail state for a fresh attempt
        _failedToday = false;
        _prefs.remove(_failKey);
        // Clear persisted grid so a fresh grid is stored next save
        _dailyService.saveGridState([], 0, 0, 0);
      },
      onOffline: () {
        if (mounted) showOfflineSnack(context);
      },
    );

    if (mounted) {
      setState(() => _loadingRestartAd = false);
    }
  }

  void _openShop() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
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
          // -- Main content --
          SafeArea(
            child: Column(
              children: [
                _buildHeader(coinService),
                const SizedBox(height: 12),

                if (_isOffline)
                  Expanded(
                    child: OfflineView(
                      message:
                          'Fjalëkryqi i ditës kërkon internet. Lidhu për të luajtur.',
                      onRetry: _initializeDaily,
                    ),
                  )
                else if (_alreadySolvedToday)
                  Expanded(child: _buildAlreadySolvedView())
                else ...[
                  if (!_isCompleted && !_game.gameLost && !_isLoading)
                    _buildInfoRow(),

                  const SizedBox(height: 12),

                  // Game board
                  if (!_isLoading)
                    ListenableBuilder(
                      listenable: _game,
                      builder: (context, _) => GameBoard(
                        game: _game,
                        tutorialHighlight: const [],
                        disableSwap: false,
                      ),
                    )
                  else
                    Expanded(child: _buildLoadingOverlay()),

                  // Small space between board and controls
                  if (!_isCompleted && !_game.gameLost && !_isLoading)
                    const SizedBox(height: 12),

                  // Bottom controls (solve/hint)
                  if (!_isCompleted && !_game.gameLost && !_isLoading)
                    _buildBottomControls(coinService),

                  // Banners
                  if (!_isCompleted && !_game.gameLost && !_isLoading) ...[
                    const SizedBox(height: 8),
                    if (_game.hintMessage.isNotEmpty && _insufficientType == null)
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
                  ],

                  // Completion section
                  if (_isCompleted)
                    _buildCompletionSection(),

                  // Lost section
                  if (_game.gameLost && !_isCompleted)
                    _buildLostSection(),
                ],

                SizedBox(height: bottomPad > 0 ? 8 : 16),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Inline banner
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

  // -- Insufficient coins inline banner --
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
                    ? 'Ju nuk keni $cost monedha \u00b7 shiko nje reklame dhe zgjidh falas'
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
    return AppTopBar(
      title: 'FJALËKRYQI I DITËS',
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

  // ══════════════════════════════════════
  //  Info row: difficulty + date | moves
  // ══════════════════════════════════════

  Widget _buildInfoRow() {
    final swapsRemaining = _game.swapsRemaining;
    final isWarning = swapsRemaining <= 10 && swapsRemaining > 5;
    final isDanger = swapsRemaining <= 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // Date
          Text(
            _todayDateLabel,
            style: AppFonts.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.45),
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
                'levizje te mbetura',
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
  //  Loading overlay
  // ══════════════════════════════════════

  static const _loadingLetters = 'ABCCDEHIMNOPRSTUVXZE';
  static const _loadingTileColors = [Color(0xFFF4B400), Color(0xFF22C55E), Color(0xFF787c7e)];

  Widget _buildLoadingOverlay() {
    final size = MediaQuery.of(context).size;
    final rng = Random(42);
    final tiles = <Widget>[];

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
  //  Already solved today view
  // ══════════════════════════════════════

  Widget _buildAlreadySolvedView() {
    final streak = _dailyService.currentStreak;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flame icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Color(0xFFFF6B35),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            // Streak count
            Text(
              '$streak',
              style: AppFonts.nunito(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF6B35),
              ),
            ),
            Text(
              'dite rresht',
              style: AppFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            // Completed message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'E zgjidhur per sot!',
                    style: AppFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4ADE80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Go back button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _audio.play(Sfx.button);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Kthehu',
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
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Completion section
  // ══════════════════════════════════════

  Widget _buildCompletionSection() {
    final streak = _dailyService.currentStreak;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // -- Streak flame --
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Color(0xFFFF6B35),
                    size: 22,
                  ),
                  Text(
                    '$streak',
                    style: AppFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
            ),

            // -- Win summary: praise + coins --
            const SizedBox(height: 6),
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
                        '+$_coinsEarned',
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

            // -- Streak text --
            const SizedBox(height: 2),
            Text(
              '$streak dite rresht',
              style: AppFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),

            // -- Go back button --
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _audio.play(Sfx.button);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
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
                    const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Kthehu',
                      style: AppFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
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

            // -- Sad flame --
            Icon(
              Icons.local_fire_department,
              size: 32,
              color: Colors.white.withValues(alpha: 0.2),
            ),

            // -- "Dshtove!" --
            const SizedBox(height: 4),
            Text(
              'Deshtove!',
              style: AppFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFCA5A5),
              ),
            ),
            const SizedBox(height: 12),

            // -- Restart with ad --
            GestureDetector(
              onTap: _loadingRestartAd ? null : _watchAdToRestart,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.35), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rinis lojën', style: AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900)),
                          Text(
                            'Ruaj streakun — mos e prish serinë!',
                            style: AppFonts.quicksand(fontSize: 10, color: const Color(0xFFFF6B35).withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    ShikoButton(
                      size: ShikoSize.medium,
                      loading: _loadingRestartAd,
                      onTap: _watchAdToRestart,
                    ),
                  ],
                ),
              ),
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
    final canAffordHintNow = coinService.canAfford(hintCost);
    final canAffordSolveNow = coinService.canAfford(solveCost);

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
                label: 'Zgjidh \u00b7 $solveCost',
                enabled: _game.canSolveWord,
                cooling: _game.solveWordCooldown,
                cooldownRemaining: _game.solveWordCooldownRemaining,
                onTap: _onSolveWord,
                showWatchBadge: !canAffordSolveNow,
                isSolve: true,
              ),
            ),
            const SizedBox(width: 10),
            // Hint button (yellow glass)
            Expanded(
              child: _controlButton(
                icon: Icons.lightbulb_outline,
                label: 'Ndihme \u00b7 $hintCost',
                enabled: _game.canHint,
                cooling: _game.hintCooldown,
                cooldownRemaining: _game.hintCooldownRemaining,
                onTap: _onHint,
                showWatchBadge: false,
                noCoins: !canAffordHintNow,
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
                  // Cooldown bar
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
