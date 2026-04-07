import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/constants/theme.dart';

/// Mock leaderboard entry — will be replaced with real data from remote DB.
class LeaderboardEntry {
  final int rank;
  final String name;
  final String? avatarUrl;
  final int value; // level or stars depending on tab
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    this.avatarUrl,
    required this.value,
    this.isCurrentUser = false,
  });
}

// Mock data for design preview
final _mockLevelLeaderboard = [
  const LeaderboardEntry(rank: 1, name: 'Arben', value: 10),
  const LeaderboardEntry(rank: 2, name: 'Elira', value: 9),
  const LeaderboardEntry(rank: 3, name: 'Dritan', value: 8),
  const LeaderboardEntry(rank: 4, name: 'Fjolla', value: 7),
  const LeaderboardEntry(rank: 5, name: 'Ti', value: 5, isCurrentUser: true),
  const LeaderboardEntry(rank: 6, name: 'Gentian', value: 4),
  const LeaderboardEntry(rank: 7, name: 'Besiana', value: 3),
];

final _mockStarsLeaderboard = [
  const LeaderboardEntry(rank: 1, name: 'Elira', value: 28),
  const LeaderboardEntry(rank: 2, name: 'Arben', value: 25),
  const LeaderboardEntry(rank: 3, name: 'Dritan', value: 21),
  const LeaderboardEntry(rank: 4, name: 'Ti', value: 14, isCurrentUser: true),
  const LeaderboardEntry(rank: 5, name: 'Fjolla', value: 12),
  const LeaderboardEntry(rank: 6, name: 'Gentian', value: 9),
  const LeaderboardEntry(rank: 7, name: 'Besiana', value: 6),
];

const _avatarColors = [
  Color(0xFF22C55E),
  Color(0xFFF4B400),
  Color(0xFF3B82F6),
  Color(0xFFE879F9),
  Color(0xFFFCA5A5),
  Color(0xFF06B6D4),
  Color(0xFFA78BFA),
];

class LeaderboardSection extends StatefulWidget {
  const LeaderboardSection({super.key});

  @override
  State<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<LeaderboardSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _tabController.index == 0
        ? _mockLevelLeaderboard
        : _mockStarsLeaderboard;
    final isLevelTab = _tabController.index == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title + tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Renditja',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              onTap: (_) => HapticFeedback.selectionClick(),
              tabs: const [
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up_rounded, size: 14),
                      SizedBox(width: 5),
                      Text('Niveli'),
                    ],
                  ),
                ),
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, size: 14),
                      SizedBox(width: 5),
                      Text('Yjet'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Top 3 podium
          _buildPodium(entries.take(3).toList(), isLevelTab),

          // Divider
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 1,
            color: Colors.white.withValues(alpha: 0.04),
          ),

          // Rest of the list
          ...entries.skip(3).map((e) => _buildRow(e, isLevelTab)),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3, bool isLevel) {
    if (top3.length < 3) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(child: _podiumItem(top3[1], isLevel, 60)),
          const SizedBox(width: 8),
          // 1st place
          Expanded(child: _podiumItem(top3[0], isLevel, 76)),
          const SizedBox(width: 8),
          // 3rd place
          Expanded(child: _podiumItem(top3[2], isLevel, 52)),
        ],
      ),
    );
  }

  Widget _podiumItem(LeaderboardEntry entry, bool isLevel, double height) {
    final isFirst = entry.rank == 1;
    final crownColor = entry.rank == 1
        ? AppColors.gold
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);
    final avatarColor = _avatarColors[(entry.name.hashCode) % _avatarColors.length];
    final bgAlpha = entry.isCurrentUser ? 0.10 : 0.05;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for top 3
        Icon(
          Icons.workspace_premium_rounded,
          color: crownColor,
          size: isFirst ? 22 : 18,
        ),
        const SizedBox(height: 2),

        // Avatar
        Container(
          width: isFirst ? 48 : 40,
          height: isFirst ? 48 : 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarColor.withValues(alpha: 0.2),
            border: Border.all(
              color: entry.isCurrentUser
                  ? AppColors.cellGreen
                  : avatarColor.withValues(alpha: 0.4),
              width: entry.isCurrentUser ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: Text(
              entry.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: isFirst ? 20 : 16,
                fontWeight: FontWeight.w800,
                color: avatarColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Name
        Text(
          entry.isCurrentUser ? 'Ti' : entry.name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: entry.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
            color: entry.isCurrentUser ? AppColors.cellGreen : Colors.white70,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),

        // Value pill
        Container(
          height: height * 0.35,
          constraints: const BoxConstraints(minHeight: 22),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: bgAlpha),
            borderRadius: BorderRadius.circular(8),
            border: entry.isCurrentUser
                ? Border.all(color: AppColors.cellGreen.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLevel ? Icons.flag_rounded : Icons.star_rounded,
                size: 12,
                color: isLevel ? AppColors.cellGreen : AppColors.gold,
              ),
              const SizedBox(width: 3),
              Text(
                '${entry.value}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: entry.isCurrentUser ? AppColors.cellGreen : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(LeaderboardEntry entry, bool isLevel) {
    final avatarColor = _avatarColors[(entry.name.hashCode) % _avatarColors.length];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.cellGreen.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: entry.isCurrentUser
            ? Border.all(color: AppColors.cellGreen.withValues(alpha: 0.15))
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 24,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: entry.isCurrentUser ? AppColors.cellGreen : Colors.white38,
              ),
            ),
          ),

          // Avatar circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withValues(alpha: 0.15),
              border: Border.all(
                color: entry.isCurrentUser
                    ? AppColors.cellGreen.withValues(alpha: 0.5)
                    : avatarColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                entry.name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Text(
              entry.isCurrentUser ? 'Ti' : entry.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: entry.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                color: entry.isCurrentUser ? AppColors.cellGreen : Colors.white70,
              ),
            ),
          ),

          // Value
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLevel ? Icons.flag_rounded : Icons.star_rounded,
                size: 14,
                color: isLevel ? AppColors.cellGreen : AppColors.gold,
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.value}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: entry.isCurrentUser ? AppColors.cellGreen : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
