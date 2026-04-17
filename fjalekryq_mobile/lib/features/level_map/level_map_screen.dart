import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/level_config.dart';
import '../../core/services/audio_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../game/game_screen.dart';

const _levelKey = 'fjalekryq_level';
const _starsKeyPrefix = 'fjalekryq_stars_';

const _albanianLetters = 'ABCDEFGHJKLMNOPRSTUVXZÇË';
const _colPattern = [0, 1, 2, 1]; // zigzag: left, center, right, center

class _LevelNode {
  final int level;
  final String letter;
  final Difficulty difficulty;
  final bool isBoss;
  final int col; // 0=left, 1=center, 2=right

  const _LevelNode({
    required this.level,
    required this.letter,
    required this.difficulty,
    required this.isBoss,
    required this.col,
  });
}

List<_LevelNode> _generateNodes() {
  return List.generate(totalMapLevels, (i) {
    final level = i + 1;
    return _LevelNode(
      level: level,
      letter: _albanianLetters[i % _albanianLetters.length],
      difficulty: difficultyForLevelExtended(level),
      isBoss: level % 10 == 0,
      col: _colPattern[i % _colPattern.length],
    );
  });
}

final _allNodes = _generateNodes();

class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _pulseController;
  int _currentLevel = 1;
  final _levelStars = <int, int>{};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final prefs = context.read<SharedPreferences>();
    _currentLevel = prefs.getInt(_levelKey) ?? 1;
    if (_currentLevel < 1) _currentLevel = 1;

    for (int level = 1; level < _currentLevel; level++) {
      _levelStars[level] = prefs.getInt('$_starsKeyPrefix$level') ?? 0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLevel();
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLevel() {
    if (!_scrollController.hasClients) return;
    // In reversed list, index 0 = level 1 (bottom). Current level's offset
    // from bottom = (_currentLevel - 1) * ~100px per row.
    // We want the current level centered in the viewport.
    final screenH = MediaQuery.of(context).size.height;
    final itemH = 100.0; // approx height per node row + connector
    // Distance from bottom where the current level sits
    final fromBottom = (_currentLevel - 1) * itemH;
    // In a reversed list, scroll offset 0 = bottom. We want current level centered.
    final offset = fromBottom - screenH / 2 + itemH;
    _scrollController.jumpTo(offset.clamp(0, _scrollController.position.maxScrollExtent));
  }

  List<_LevelNode> get _visibleNodes {
    final lastVisible = (_currentLevel + visibleLockedLevels).clamp(0, totalMapLevels);
    return _allNodes.sublist(0, lastVisible);
  }

  String _getState(int level) {
    if (level < _currentLevel) return 'completed';
    if (level == _currentLevel) return 'current';
    return 'locked';
  }

  int _getStars(int level) => _levelStars[level] ?? 0;

  int get _totalStars => _levelStars.values.fold(0, (sum, s) => sum + s);

  void _selectLevel(int level) {
    if (_getState(level) == 'locked') return;
    HapticFeedback.mediumImpact();
    context.read<AudioService>().play(Sfx.levelSelect);
    final prefs = context.read<SharedPreferences>();
    prefs.setInt('fjalekryq_playing_level', level);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const GameScreen(),
    )).then((_) {
      setState(() {
        _currentLevel = prefs.getInt(_levelKey) ?? 1;
        for (int l = 1; l < _currentLevel; l++) {
          _levelStars[l] = prefs.getInt('$_starsKeyPrefix$l') ?? 0;
        }
      });
    });
  }

  Color _diffColor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:   return AppColors.diffEasy;
      case Difficulty.medium: return AppColors.diffMedium;
      case Difficulty.hard:   return AppColors.diffHard;
      case Difficulty.expert: return AppColors.diffExpert;
    }
  }

  // Matching web labels
  String _diffLabel(Difficulty d) {
    switch (d) {
      case Difficulty.easy:   return 'E lehtë';
      case Difficulty.medium: return 'Mesatare';
      case Difficulty.hard:   return 'E vështirë';
      case Difficulty.expert: return 'Ekspert';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _visibleNodes;
    final hiddenCount = totalMapLevels - nodes.length;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
        children: [
          // Map body (reversed: level 1 at bottom, matching web column-reverse)
          Positioned.fill(
            top: statusBarHeight + 60,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 24),
              reverse: true, // level 1 at bottom like web
              itemCount: nodes.length + (hiddenCount > 0 ? 1 : 0),
              itemBuilder: (context, index) {
                // Fog zone at the "top" (which is bottom in reversed list)
                if (index >= nodes.length) {
                  return _buildFogZone(hiddenCount);
                }

                final node = nodes[index];
                final state = _getState(node.level);
                final stars = _getStars(node.level);
                final diffColor = _diffColor(node.difficulty);

                return _buildNodeRow(node, state, stars, diffColor);
              },
            ),
          ),

          // Header (matching web .map-header)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(statusBarHeight),
          ),

          // Tutorial button (bottom-right)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<AudioService>().play(Sfx.button);
                final prefs = context.read<SharedPreferences>();
                prefs.setBool('fjalekryq_force_tutorial', true);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const GameScreen(),
                )).then((_) {
                  setState(() {
                    final prefs = context.read<SharedPreferences>();
                    _currentLevel = prefs.getInt(_levelKey) ?? 1;
                    for (int l = 1; l < _currentLevel; l++) {
                      _levelStars[l] = prefs.getInt('$_starsKeyPrefix$l') ?? 0;
                    }
                  });
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline_rounded, color: Colors.white.withValues(alpha: 0.8), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Si të luash',
                      style: AppFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(double statusBarHeight) {
    return Padding(
      padding: EdgeInsets.only(top: statusBarHeight),
      child: AppTopBar(
        title: 'HARTA E LOJËS',
        trailing: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.gold, size: 15),
              const SizedBox(width: 5),
              Text(
                '$_totalStars',
                style: AppFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeRow(_LevelNode node, String state, int stars, Color diffColor) {
    // Alignment: col-0=left(8%), col-1=center, col-2=right(8%)
    final alignment = node.col == 0
        ? Alignment.centerLeft
        : node.col == 2
            ? Alignment.centerRight
            : Alignment.center;

    final edgePadding = node.col == 0
        ? const EdgeInsets.only(left: 32)
        : node.col == 2
            ? const EdgeInsets.only(right: 32)
            : EdgeInsets.zero;

    return Column(
      children: [
        // Connector bar (matching web .connector)
        _buildConnector(state),

        // Node with diff badge
        Padding(
          padding: edgePadding,
          child: Align(
            alignment: alignment,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Diff badge on left side for col-2
                if (state != 'locked' && node.col == 2)
                  _buildDiffBadge(node.difficulty, diffColor),

                // Level tile
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GestureDetector(
                    onTap: () => _selectLevel(node.level),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final isCurrent = state == 'current';
                        final bounce = isCurrent ? -5 * _pulseController.value : 0.0;
                        final scale = isCurrent ? 1.0 + _pulseController.value * 0.04 : 1.0;
                        return Transform.translate(
                          offset: Offset(0, bounce),
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: _LevelTile(
                        level: node.level,
                        letter: node.letter,
                        state: state,
                        stars: stars,
                        isBoss: node.isBoss,
                        diffColor: diffColor,
                      ),
                    ),
                  ),
                ),

                // Diff badge on right side for col-0 and col-1
                if (state != 'locked' && node.col != 2)
                  _buildDiffBadge(node.difficulty, diffColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Matching web .diff-badge (pill shape)
  Widget _buildDiffBadge(Difficulty diff, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          _diffLabel(diff),
          style: AppFonts.nunito(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // Matching web .connector (simple vertical bar)
  Widget _buildConnector(String state) {
    Color color;
    if (state == 'completed') {
      color = AppColors.cellGreen.withValues(alpha: 0.6);
    } else if (state == 'current') {
      color = AppColors.gold.withValues(alpha: 0.5);
    } else {
      color = Colors.white.withValues(alpha: 0.1);
    }

    return Center(
      child: Container(
        width: 4,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // Matching web .fog-zone
  Widget _buildFogZone(int hiddenCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // 5 blurred ghost tiles
          Opacity(
            opacity: 0.3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final size = (i == 0 || i == 2) ? 64.0 : 56.0;
                final op = i == 4 ? 0.5 : (i % 2 == 0 ? 0.9 : 0.7);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Opacity(
                    opacity: op,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Icon(Icons.group_outlined, color: Colors.white.withValues(alpha: 0.4), size: 18),
          const SizedBox(height: 6),
          Text(
            '$hiddenCount+ nivele të pazbuluara',
            style: AppFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.45),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Zgjidh nivelet për të zbuluar botë të reja!',
            style: AppFonts.quicksand(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Level tile (matching web .tile-node) ──

class _LevelTile extends StatelessWidget {
  final int level;
  final String letter;
  final String state;
  final int stars;
  final bool isBoss;
  final Color diffColor;

  const _LevelTile({
    required this.level,
    required this.letter,
    required this.state,
    required this.stars,
    required this.isBoss,
    required this.diffColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = state == 'locked';
    final isCurrent = state == 'current';
    final isCompleted = state == 'completed';

    final tileSize = isBoss ? 80.0 : 68.0;
    final borderRadius = isBoss ? 18.0 : 14.0;

    Gradient? gradient;
    Color borderColor;
    List<BoxShadow> shadows = [];

    if (isCompleted) {
      gradient = const LinearGradient(
        begin: Alignment(-0.5, -1),
        end: Alignment(0.5, 1),
        colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
      );
      borderColor = Colors.white.withValues(alpha: 0.25);
      shadows = [
        BoxShadow(
          color: AppColors.cellGreen.withValues(alpha: 0.5),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
    } else if (isCurrent) {
      gradient = const LinearGradient(
        begin: Alignment(-0.5, -1),
        end: Alignment(0.5, 1),
        colors: [Color(0xFFFFD43B), Color(0xFFF59E0B)],
      );
      borderColor = Colors.white.withValues(alpha: 0.3);
      shadows = [
        BoxShadow(
          color: AppColors.gold.withValues(alpha: 0.65),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];
    } else {
      gradient = null;
      borderColor = Colors.white.withValues(alpha: 0.08);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Boss crown
        if (isBoss && !isLocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('👑', style: TextStyle(fontSize: isCurrent ? 20 : 16)),
          ),

        Stack(
          clipBehavior: Clip.none,
          children: [
            // Current ring (matching web .current-ring)
            if (isCurrent)
              Positioned(
                top: -9, left: -9, right: -9, bottom: -9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius + 8),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.55),
                      width: 2.5,
                    ),
                  ),
                ),
              ),

            // Main tile
            Container(
              width: tileSize,
              height: tileSize,
              decoration: BoxDecoration(
                gradient: gradient,
                color: isLocked ? const Color(0xFF0F2251).withValues(alpha: 0.8) : null,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: shadows,
              ),
              child: Opacity(
                opacity: isLocked ? 0.6 : 1.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLocked)
                      Icon(Icons.lock_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 18,
                      )
                    else
                      Text(
                        letter,
                        style: AppFonts.nunito(
                          fontSize: isBoss ? 28 : 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    const SizedBox(height: 1),
                    Text(
                      '$level',
                      style: AppFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isLocked
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Checkmark badge (matching web .tile-check)
            if (isCompleted)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),

        // Stars below completed (matching web .node-stars)
        if (isCompleted && stars > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: i < stars
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.2),
                ),
              )),
            ),
          ),
      ],
    );
  }
}
