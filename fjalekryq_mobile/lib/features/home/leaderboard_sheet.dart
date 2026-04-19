import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/offline_view.dart';
import 'leaderboard_data.dart';
import 'leaderboard_full_screen.dart';

// ─── Preview bottom sheet ─────────────────────────────────────────────────────
class LeaderboardPreviewSheet extends StatefulWidget {
  const LeaderboardPreviewSheet({super.key});

  @override
  State<LeaderboardPreviewSheet> createState() => _LeaderboardPreviewSheetState();
}

class _LeaderboardPreviewSheetState extends State<LeaderboardPreviewSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lazy per-tab load state (see leaderboard_full_screen.dart for the
  // same pattern — we keep the preview sheet and the full screen in sync
  // by driving both from `loadLeaderboard`).
  final Map<LeaderboardTab, LeaderboardLoadResult?> _results = {
    for (final t in LeaderboardTab.values) t: null,
  };
  final Set<LeaderboardTab> _loading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
      _fetchIfNeeded(_currentTab);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchIfNeeded(_currentTab);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  LeaderboardTab get _currentTab => LeaderboardTab.values[_tabController.index];

  Future<void> _fetchIfNeeded(LeaderboardTab tab) async {
    if (_results[tab] != null || _loading.contains(tab)) return;
    setState(() => _loading.add(tab));
    final result = await loadLeaderboard(tab);
    if (!mounted) return;
    setState(() {
      _results[tab] = result;
      _loading.remove(tab);
    });
  }

  Future<void> _retry(LeaderboardTab tab) async {
    setState(() => _results[tab] = null);
    await _fetchIfNeeded(tab);
  }

  @override
  Widget build(BuildContext context) {
    final tab = _currentTab;
    final result = _results[tab];
    final valueColor = valueColorForTab(tab);

    // Extract the entries (or null if still loading / offline / errored)
    // from the current-tab result. Later in the build we branch on this
    // to show a placeholder block instead of the row list.
    List<LeaderboardEntry>? allEntries;
    if (result is LeaderboardData) {
      allEntries = result.entries;
    }

    final top10 = (allEntries ?? const <LeaderboardEntry>[])
        .where((e) => e.rank <= 10)
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final userEntry =
        (allEntries ?? const <LeaderboardEntry>[]).where((e) => e.isCurrentUser).firstOrNull;
    final userInTop10 = userEntry != null && userEntry.rank <= 10;

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

          // Body — dispatches on load state.
          if (_loading.contains(tab) || result == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          else if (result is LeaderboardOffline)
            SizedBox(
              height: 240,
              child: OfflineView(
                message: 'Kërkohet internet për të parë renditjen.',
                onRetry: () => _retry(tab),
              ),
            )
          else if (result is LeaderboardError)
            SizedBox(
              height: 240,
              child: OfflineView(
                message: (result).message,
                onRetry: () => _retry(tab),
              ),
            )
          else if (allEntries != null && allEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Asnjë lojtar ende.',
                  style: AppFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else ...[
            // Top 10 rows
            ...top10.map((e) => _buildRow(e, valueColor)),

            // Sticky user row (if not in top 10)
            if (!userInTop10 && userEntry != null)
              _buildUserSticky(userEntry, valueColor),
          ],

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
