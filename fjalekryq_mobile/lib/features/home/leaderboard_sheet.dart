import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/constants/theme.dart';
import 'leaderboard_full_screen.dart';

// ─── Avatar options (shared with settings) ───────────────────────────────────
const avatarOptions = [
  (color: Color(0xFF22C55E), icon: Icons.person_rounded),             // 0 green
  (color: Color(0xFFF4B400), icon: Icons.person_rounded),             // 1 yellow
  (color: Color(0xFF3B82F6), icon: Icons.person_rounded),             // 2 blue
  (color: Color(0xFFEF4444), icon: Icons.person_rounded),             // 3 red
  (color: Color(0xFFFFD700), icon: Icons.workspace_premium_rounded),  // 4 crown
  (color: Color(0xFF60A5FA), icon: Icons.rocket_launch_rounded),      // 5 rocket
  (color: Color(0xFFF4B400), icon: Icons.emoji_events_rounded),       // 6 trophy
  (color: Color(0xFF8B5CF6), icon: Icons.auto_awesome_rounded),       // 7 sparkle
  (color: Color(0xFFF59E0B), icon: Icons.bolt_rounded),               // 8 bolt
  (color: Color(0xFFEC4899), icon: Icons.favorite_rounded),           // 9 heart
  (color: Color(0xFFFF6B35), icon: Icons.local_fire_department_rounded), // 10 fire
  (color: Color(0xFF22C55E), icon: Icons.star_rounded),               // 11 star
];

// ─── Model ────────────────────────────────────────────────────────────────────
class LeaderboardEntry {
  final int rank;
  final String name;
  final int value;
  final bool isCurrentUser;
  final int? avatarIndex;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.value,
    this.isCurrentUser = false,
    this.avatarIndex,
  });
}

// ─── Tab enum (public — shared with full screen) ──────────────────────────────
enum LeaderboardTab {
  level(icon: Icons.emoji_events_outlined, label: 'Niveli'),
  stars(icon: Icons.star_rounded, label: 'Yjet'),
  streak(icon: Icons.local_fire_department_rounded, label: 'Ditore');

  final IconData icon;
  final String label;
  const LeaderboardTab({required this.icon, required this.label});
}

// ─── Mock data ────────────────────────────────────────────────────────────────
// Levels: user at rank 23 — not in top 10 → sticky "Ti je #23" row shown
final mockLevelLeaderboard = <LeaderboardEntry>[
  const LeaderboardEntry(rank: 1,  name: 'Arben_94',   value: 45,  avatarIndex: 10),
  const LeaderboardEntry(rank: 2,  name: 'Elira_K',    value: 42,  avatarIndex: 9),
  const LeaderboardEntry(rank: 3,  name: 'Dritan_B',   value: 38,  avatarIndex: 8),
  const LeaderboardEntry(rank: 4,  name: 'Fjolla_X',   value: 35,  avatarIndex: 3),
  const LeaderboardEntry(rank: 5,  name: 'Gentian_M',  value: 30,  avatarIndex: 14),
  const LeaderboardEntry(rank: 6,  name: 'Besiana',    value: 27,  avatarIndex: 13),
  const LeaderboardEntry(rank: 7,  name: 'Klea_S',     value: 24,  avatarIndex: 15),
  const LeaderboardEntry(rank: 8,  name: 'Alban_R',    value: 22,  avatarIndex: 1),
  const LeaderboardEntry(rank: 9,  name: 'Mimoza_H',   value: 20,  avatarIndex: 4),
  const LeaderboardEntry(rank: 10, name: 'Edona_T',    value: 18,  avatarIndex: 11),
  const LeaderboardEntry(rank: 23, name: 'Ti',         value: 12,  avatarIndex: 0, isCurrentUser: true),
];

// Stars: user at rank 4 — IN top 10 → highlighted in place
final mockStarsLeaderboard = <LeaderboardEntry>[
  const LeaderboardEntry(rank: 1,  name: 'Elira_K',    value: 135, avatarIndex: 9),
  const LeaderboardEntry(rank: 2,  name: 'Arben_94',   value: 126, avatarIndex: 10),
  const LeaderboardEntry(rank: 3,  name: 'Dritan_B',   value: 114, avatarIndex: 8),
  const LeaderboardEntry(rank: 4,  name: 'Ti',         value: 42,  avatarIndex: 0, isCurrentUser: true),
  const LeaderboardEntry(rank: 5,  name: 'Fjolla_X',   value: 38,  avatarIndex: 3),
  const LeaderboardEntry(rank: 6,  name: 'Gentian_M',  value: 31,  avatarIndex: 14),
  const LeaderboardEntry(rank: 7,  name: 'Besiana',    value: 24,  avatarIndex: 13),
  const LeaderboardEntry(rank: 8,  name: 'Klea_S',     value: 19,  avatarIndex: 15),
  const LeaderboardEntry(rank: 9,  name: 'Mimoza_H',   value: 15,  avatarIndex: 4),
  const LeaderboardEntry(rank: 10, name: 'Alban_R',    value: 12,  avatarIndex: 1),
];

// Streak: user at rank 12 — not in top 10 → sticky row shown
final mockStreakLeaderboard = <LeaderboardEntry>[
  const LeaderboardEntry(rank: 1,  name: 'Dritan_B',   value: 42,  avatarIndex: 8),
  const LeaderboardEntry(rank: 2,  name: 'Elira_K',    value: 35,  avatarIndex: 9),
  const LeaderboardEntry(rank: 3,  name: 'Arben_94',   value: 28,  avatarIndex: 10),
  const LeaderboardEntry(rank: 4,  name: 'Fjolla_X',   value: 21,  avatarIndex: 3),
  const LeaderboardEntry(rank: 5,  name: 'Klea_S',     value: 18,  avatarIndex: 15),
  const LeaderboardEntry(rank: 6,  name: 'Gentian_M',  value: 15,  avatarIndex: 14),
  const LeaderboardEntry(rank: 7,  name: 'Besiana',    value: 12,  avatarIndex: 13),
  const LeaderboardEntry(rank: 8,  name: 'Alban_R',    value: 10,  avatarIndex: 1),
  const LeaderboardEntry(rank: 9,  name: 'Edona_T',    value: 9,   avatarIndex: 11),
  const LeaderboardEntry(rank: 10, name: 'Mimoza_H',   value: 8,   avatarIndex: 4),
  const LeaderboardEntry(rank: 12, name: 'Ti',         value: 6,   avatarIndex: 0, isCurrentUser: true),
];

List<LeaderboardEntry> entriesForTab(LeaderboardTab tab) {
  switch (tab) {
    case LeaderboardTab.level:  return mockLevelLeaderboard;
    case LeaderboardTab.stars:  return mockStarsLeaderboard;
    case LeaderboardTab.streak: return mockStreakLeaderboard;
  }
}

Color valueColorForTab(LeaderboardTab tab) {
  switch (tab) {
    case LeaderboardTab.level:  return AppColors.cellGreen;
    case LeaderboardTab.stars:  return AppColors.gold;
    case LeaderboardTab.streak: return const Color(0xFFFF6B35);
  }
}

// ─── Preview bottom sheet ─────────────────────────────────────────────────────
class LeaderboardPreviewSheet extends StatefulWidget {
  const LeaderboardPreviewSheet({super.key});

  @override
  State<LeaderboardPreviewSheet> createState() => _LeaderboardPreviewSheetState();
}

class _LeaderboardPreviewSheetState extends State<LeaderboardPreviewSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  LeaderboardTab get _currentTab => LeaderboardTab.values[_tabController.index];

  @override
  Widget build(BuildContext context) {
    final tab = _currentTab;
    final allEntries = entriesForTab(tab);
    final top10 = allEntries.where((e) => e.rank <= 10).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final userEntry = allEntries.where((e) => e.isCurrentUser).firstOrNull;
    final userInTop10 = userEntry != null && userEntry.rank <= 10;
    final valueColor = valueColorForTab(tab);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF142452), Color(0xFF0D1B40)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title + close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Renditja',
                  style: AppFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, color: Colors.white38, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tabs
          _buildTabBar(),
          const SizedBox(height: 6),

          // Top 10 rows
          ...top10.map((e) => _buildRow(e, valueColor)),

          // Sticky user row (if not in top 10)
          if (!userInTop10 && userEntry != null)
            _buildUserSticky(userEntry, valueColor),

          const SizedBox(height: 10),

          // View All button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LeaderboardFullScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.purpleAccent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Shiko të gjitha',
                      style: AppFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE2C9FF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, color: Color(0xFFE2C9FF), size: 12),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
        labelStyle: AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500),
        labelPadding: EdgeInsets.zero,
        onTap: (_) => HapticFeedback.selectionClick(),
        tabs: LeaderboardTab.values.map((tab) => Tab(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 14),
              const SizedBox(width: 4),
              Text(tab.label),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRow(LeaderboardEntry entry, Color valueColor) {
    final idx = entry.avatarIndex ?? entry.name.hashCode.abs() % avatarOptions.length;
    final avatar = avatarOptions[idx % avatarOptions.length];
    final avatarColor = avatar.color;
    final isTop3 = entry.rank <= 3;

    Color? medalColor;
    if (entry.rank == 1) medalColor = AppColors.gold;
    else if (entry.rank == 2) medalColor = const Color(0xFFC0C0C0);
    else if (entry.rank == 3) medalColor = const Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.cellGreen.withValues(alpha: 0.08)
            : isTop3
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: entry.isCurrentUser
            ? Border.all(color: AppColors.cellGreen.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          // Rank / medal
          SizedBox(
            width: 28,
            child: medalColor != null
                ? Icon(Icons.workspace_premium_rounded, color: medalColor, size: 18)
                : Text(
                    '${entry.rank}',
                    style: AppFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: entry.isCurrentUser ? AppColors.cellGreen : Colors.white38,
                    ),
                  ),
          ),
          // Avatar
          Container(
            width: 34, height: 34,
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
              child: Icon(avatar.icon, color: avatarColor, size: 17),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              entry.isCurrentUser ? 'Ti' : entry.name,
              style: AppFonts.nunito(
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
              Icon(_currentTab.icon, size: 13, color: valueColor),
              const SizedBox(width: 4),
              Text(
                '${entry.value}',
                style: AppFonts.nunito(
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

  Widget _buildUserSticky(LeaderboardEntry userEntry, Color valueColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Ti je #${userEntry.rank}',
                  style: AppFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cellGreen.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
            ],
          ),
        ),
        _buildRow(userEntry, valueColor),
      ],
    );
  }
}
