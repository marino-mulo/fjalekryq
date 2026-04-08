import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/level_config.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/audio_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/coin_badge.dart';
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

// Alignment values for columns (left, center, right)
const _colAlignments = [-0.6, 0.0, 0.6];

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
    )..repeat(reverse: true);

    final prefs = context.read<SharedPreferences>();
    _currentLevel = prefs.getInt(_levelKey) ?? 1;
    if (_currentLevel < 1) _currentLevel = 1;

    for (int level = 1; level <= totalMapLevels; level++) {
      _levelStars[level] = prefs.getInt('$_starsKeyPrefix$level') ?? 0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentLevel());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLevel() {
    final index = _currentLevel - 1;
    final offset = (index * 84.0) - MediaQuery.of(context).size.height / 2 + 40;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(offset.clamp(0, _scrollController.position.maxScrollExtent));
    }
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
        for (int l = 1; l <= totalMapLevels; l++) {
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

  @override
  Widget build(BuildContext context) {
    final coinService = context.watch<CoinService>();
    final nodes = _visibleNodes;
    final hiddenCount = totalMapLevels - nodes.length;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07152F), Color(0xFF0D1B40), Color(0xFF142452)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
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
                    const SizedBox(width: 12),
                    // Total stars badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalStars',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    CoinBadge(amount: coinService.coins),
                  ],
                ),
              ),

              // Level list with connecting lines
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: nodes.length + (hiddenCount > 0 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= nodes.length) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+$hiddenCount nivele të tjera...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final node = nodes[index];
                    final state = _getState(node.level);
                    final stars = _getStars(node.level);
                    final diffColor = _diffColor(node.difficulty);
                    final alignment = _colAlignments[node.col];

                    // Calculate line to next node
                    final hasNext = index + 1 < nodes.length;

                    return Column(
                      children: [
                        // Level tile
                        Align(
                          alignment: Alignment(alignment, 0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: GestureDetector(
                              onTap: () => _selectLevel(node.level),
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  final isCurrent = state == 'current';
                                  final pulseScale = isCurrent
                                      ? 1.0 + _pulseController.value * 0.04
                                      : 1.0;
                                  return Transform.scale(
                                    scale: pulseScale,
                                    child: child,
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
                        ),

                        // Connecting dotted line to next node
                        if (hasNext)
                          _buildConnector(
                            screenWidth,
                            node.col,
                            nodes[index + 1].col,
                            state != 'locked',
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Draws a subtle dotted connector between two level nodes.
  Widget _buildConnector(double screenWidth, int fromCol, int toCol, bool active) {
    final fromX = screenWidth / 2 + _colAlignments[fromCol] * screenWidth / 2;
    final toX = screenWidth / 2 + _colAlignments[toCol] * screenWidth / 2;

    return SizedBox(
      height: 24,
      child: CustomPaint(
        size: Size(screenWidth, 24),
        painter: _ConnectorPainter(
          fromX: fromX,
          toX: toX,
          active: active,
        ),
      ),
    );
  }
}

/// Paints a dotted line between two column positions.
class _ConnectorPainter extends CustomPainter {
  final double fromX;
  final double toX;
  final bool active;

  _ConnectorPainter({
    required this.fromX,
    required this.toX,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw dotted line
    const dashLen = 4.0;
    const gapLen = 6.0;
    final dx = toX - fromX;
    final dy = size.height;
    final length = (dx * dx + dy * dy);
    final steps = length > 0 ? (length / ((dashLen + gapLen) * (dashLen + gapLen))).ceil() : 4;

    for (int i = 0; i < (steps > 0 ? steps : 4); i++) {
      final t1 = i / (steps > 0 ? steps : 4);
      final t2 = (i + 0.4) / (steps > 0 ? steps : 4);
      canvas.drawLine(
        Offset(fromX + dx * t1, dy * t1),
        Offset(fromX + dx * t2.clamp(0, 1), dy * t2.clamp(0, 1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.fromX != fromX || old.toX != toX || old.active != active;
}

class _LevelTile extends StatelessWidget {
  final int level;
  final String letter;
  final String state; // 'completed', 'current', 'locked'
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

    final tileSize = isBoss ? 66.0 : 58.0;
    final borderRadius = isBoss ? 18.0 : 14.0;

    Color bgColor;
    if (isLocked) {
      bgColor = Colors.white.withValues(alpha: 0.04);
    } else if (isCurrent) {
      bgColor = AppColors.cellGreen.withValues(alpha: 0.2);
    } else {
      bgColor = AppColors.surface.withValues(alpha: 0.8);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stars row
        if (isCompleted && stars > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: i < stars ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
                ),
              )),
            ),
          ),

        // Tile
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: isCurrent
                ? Border.all(color: AppColors.cellGreen, width: 2.5)
                : isCompleted
                    ? Border.all(color: diffColor.withValues(alpha: 0.35), width: 1.5)
                    : Border.all(color: Colors.white.withValues(alpha: 0.04)),
            boxShadow: [
              if (isCurrent) ...[
                BoxShadow(
                  color: AppColors.cellGreen.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
              if (isCompleted)
                BoxShadow(
                  color: diffColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLocked)
                Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.15), size: 20)
              else
                Text(
                  letter,
                  style: TextStyle(
                    fontSize: isBoss ? 24 : 20,
                    fontWeight: FontWeight.w800,
                    color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              const SizedBox(height: 1),
              Text(
                '$level',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isLocked
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),

        // Difficulty label for current level
        if (isCurrent)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cellGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                difficultyLabel(Difficulty.values.firstWhere(
                  (d) => _diffColorFor(d) == diffColor,
                  orElse: () => Difficulty.easy,
                )),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: diffColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _diffColorFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:   return AppColors.diffEasy;
      case Difficulty.medium: return AppColors.diffMedium;
      case Difficulty.hard:   return AppColors.diffHard;
      case Difficulty.expert: return AppColors.diffExpert;
    }
  }
}
