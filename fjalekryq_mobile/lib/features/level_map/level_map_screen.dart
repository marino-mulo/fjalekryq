import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/level_config.dart';
import '../../core/services/coin_service.dart';
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

class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  late ScrollController _scrollController;
  int _currentLevel = 1;
  final _levelStars = <int, int>{};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final prefs = context.read<SharedPreferences>();
    _currentLevel = prefs.getInt(_levelKey) ?? 1;
    if (_currentLevel < 1) _currentLevel = 1;

    for (int level = 1; level <= totalMapLevels; level++) {
      _levelStars[level] = prefs.getInt('$_starsKeyPrefix$level') ?? 0;
    }

    // Scroll to current level after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentLevel());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLevel() {
    // Each row is about 80px high
    final index = _currentLevel - 1;
    final offset = (index * 80.0) - MediaQuery.of(context).size.height / 2 + 40;
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
    final prefs = context.read<SharedPreferences>();
    prefs.setInt('fjalekryq_playing_level', level);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const GameScreen(),
    )).then((_) {
      // Refresh when coming back
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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total stars badge
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.gold, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$_totalStars',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    CoinBadge(amount: coinService.coins),
                  ],
                ),
              ),

              // Level grid
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: nodes.length + (hiddenCount > 0 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= nodes.length) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            '+$hiddenCount nivele të tjera...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }

                    final node = nodes[index];
                    final state = _getState(node.level);
                    final stars = _getStars(node.level);
                    final diffColor = _diffColor(node.difficulty);

                    // Position based on column pattern
                    double alignment;
                    switch (node.col) {
                      case 0: alignment = -0.6; break;
                      case 2: alignment = 0.6; break;
                      default: alignment = 0.0;
                    }

                    return Align(
                      alignment: Alignment(alignment, 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GestureDetector(
                          onTap: () => _selectLevel(node.level),
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

    final tileSize = isBoss ? 64.0 : 56.0;
    final borderRadius = isBoss ? 16.0 : 14.0;

    Color bgColor;
    if (isLocked) {
      bgColor = Colors.white.withValues(alpha: 0.05);
    } else if (isCurrent) {
      bgColor = AppColors.cellGreen.withValues(alpha: 0.25);
    } else {
      bgColor = AppColors.surface;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stars row (only for completed levels)
        if (isCompleted && stars > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Icon(
                Icons.star,
                size: 12,
                color: i < stars ? AppColors.gold : Colors.white12,
              )),
            ),
          ),

        // Level tile
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: isCurrent
                ? Border.all(color: AppColors.cellGreen, width: 2.5)
                : isCompleted
                    ? Border.all(color: diffColor.withValues(alpha: 0.4), width: 1.5)
                    : null,
            boxShadow: isCurrent
                ? [BoxShadow(color: AppColors.cellGreen.withValues(alpha: 0.3), blurRadius: 12)]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLocked ? '🔒' : letter,
                style: TextStyle(
                  fontSize: isBoss ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: isLocked ? Colors.white24 : Colors.white,
                ),
              ),
              Text(
                '$level',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isLocked ? Colors.white12 : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
