import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_loading_view.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/offline_view.dart';
import 'leaderboard_data.dart';

/// Full-screen leaderboard opened from "Shiko të gjitha" in the preview sheet.
class LeaderboardFullScreen extends StatefulWidget {
  const LeaderboardFullScreen({super.key});

  @override
  State<LeaderboardFullScreen> createState() => _LeaderboardFullScreenState();
}

class _LeaderboardFullScreenState extends State<LeaderboardFullScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Per-tab load state. Fetched lazily the first time a tab is viewed,
  // kept in memory afterwards so re-selecting the tab doesn't reload.
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
    // Kick off the first tab.
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: LeaderboardTab.values
                      .map((tab) => _buildTabContent(tab))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const AppTopBar(
          title: 'RENDITJA',
          titleIcon: Icons.emoji_events_rounded,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _buildTabBar(),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
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
        unselectedLabelStyle:
            AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500),
        labelPadding: EdgeInsets.zero,
        onTap: (_) => HapticFeedback.selectionClick(),
        tabs: LeaderboardTab.values
            .map((tab) => Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab.icon, size: 14),
                      const SizedBox(width: 4),
                      Text(tab.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─── Tab content ─────────────────────────────────────────────────────────────

  Widget _buildTabContent(LeaderboardTab tab) {
    // ── Load state dispatch ────────────────────────────────────────────────
    if (_loading.contains(tab) || _results[tab] == null) {
      return const AppLoadingIndicator();
    }
    final result = _results[tab]!;
    if (result is LeaderboardOffline) {
      return OfflineView(
        message: 'Kërkohet internet për të parë renditjen.',
        onRetry: () => _retry(tab),
      );
    }
    if (result is LeaderboardError) {
      return OfflineView(
        message: result.message,
        onRetry: () => _retry(tab),
      );
    }

    final allEntries = (result as LeaderboardData).entries;
    if (allEntries.isEmpty) {
      return Center(
        child: Text(
          'Asnjë lojtar ende.',
          style: AppFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    final sorted = [...allEntries]..sort((a, b) => a.rank.compareTo(b.rank));
    final top10 = sorted.where((e) => e.rank <= 10).toList();
    final userEntry = sorted.where((e) => e.isCurrentUser).firstOrNull;
    final userInTop10 = userEntry != null && userEntry.rank <= 10;
    final valueColor = valueColorForTab(tab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Podium — fixed height, not scrollable
        if (top10.length >= 3)
          _buildPodium(top10.take(3).toList(), tab, valueColor),

        // Thin divider
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          height: 1,
          color: Colors.white.withValues(alpha: 0.06),
        ),

        // Ranks 4–10 + user sticky — scrollable, fills remaining space
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ...top10.skip(3).map((e) => _buildRow(e, tab, valueColor)),
              if (!userInTop10 && userEntry != null)
                _buildUserSticky(userEntry, tab, valueColor),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Podium ───────────────────────────────────────────────────────────────────

  Widget _buildPodium(
      List<LeaderboardEntry> top3, LeaderboardTab tab, Color valueColor) {
    // Layout: 2nd | 1st | 3rd
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumItem(top3[1], 72, tab, valueColor)),
          const SizedBox(width: 8),
          Expanded(child: _podiumItem(top3[0], 96, tab, valueColor)),
          const SizedBox(width: 8),
          Expanded(child: _podiumItem(top3[2], 56, tab, valueColor)),
        ],
      ),
    );
  }

  Widget _podiumItem(LeaderboardEntry entry, double pedHeight,
      LeaderboardTab tab, Color valueColor) {
    final isFirst = entry.rank == 1;
    final crownColor = entry.rank == 1
        ? AppColors.gold
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);
    final idx = entry.avatarIndex ?? entry.name.hashCode.abs() % avatarOptions.length;
    final avatar = avatarOptions[idx % avatarOptions.length];
    final avatarColor = avatar.color;

    // Pedestal tint for 1st place
    final pedColor = isFirst
        ? AppColors.gold.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.05);
    final pedBorder = isFirst
        ? AppColors.gold.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.08);
    final avatarSize = isFirst ? 58.0 : 46.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown
        Icon(Icons.workspace_premium_rounded,
            color: crownColor, size: isFirst ? 28 : 22),
        const SizedBox(height: 6),

        // Avatar
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarColor.withValues(alpha: 0.18),
            border: Border.all(
              color: entry.isCurrentUser
                  ? AppColors.cellGreen
                  : avatarColor.withValues(alpha: 0.5),
              width: entry.isCurrentUser ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                  color: avatarColor.withValues(alpha: 0.28), blurRadius: 14),
            ],
          ),
          child: Center(
            child: Icon(avatar.icon, color: avatarColor, size: avatarSize * 0.46),
          ),
        ),
        const SizedBox(height: 8),

        // Name
        Text(
          entry.isCurrentUser ? 'Ti' : entry.name.split('_').first,
          style: AppFonts.nunito(
            fontSize: 12,
            fontWeight:
                entry.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
            color:
                entry.isCurrentUser ? AppColors.cellGreen : Colors.white70,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

        // Pedestal with value (horizontal icon + number)
        Container(
          height: pedHeight,
          decoration: BoxDecoration(
            color: pedColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pedBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 13, color: valueColor),
              const SizedBox(width: 4),
              Text(
                '${entry.value}',
                style: AppFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isFirst ? AppColors.gold : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Regular row ──────────────────────────────────────────────────────────────

  Widget _buildRow(
      LeaderboardEntry entry, LeaderboardTab tab, Color valueColor) {
    final idx = entry.avatarIndex ?? entry.name.hashCode.abs() % avatarOptions.length;
    final avatar = avatarOptions[idx % avatarOptions.length];
    final avatarColor = avatar.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.cellGreen.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: entry.isCurrentUser
            ? Border.all(color: AppColors.cellGreen.withValues(alpha: 0.22))
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 30,
            child: Text(
              '${entry.rank}',
              style: AppFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color:
                    entry.isCurrentUser ? AppColors.cellGreen : Colors.white38,
              ),
            ),
          ),
          // Avatar
          Container(
            width: 38, height: 38,
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
              child: Icon(avatar.icon, color: avatarColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              entry.isCurrentUser ? 'Ti' : entry.name,
              style: AppFonts.nunito(
                fontSize: 14,
                fontWeight:
                    entry.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                color:
                    entry.isCurrentUser ? AppColors.cellGreen : Colors.white70,
              ),
            ),
          ),
          // Value
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 15, color: valueColor),
              const SizedBox(width: 5),
              Text(
                '${entry.value}',
                style: AppFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: entry.isCurrentUser
                      ? AppColors.cellGreen
                      : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Sticky user row ─────────────────────────────────────────────────────────

  Widget _buildUserSticky(LeaderboardEntry userEntry, LeaderboardTab tab,
      Color valueColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                  child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08))),
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
              Expanded(
                  child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08))),
            ],
          ),
        ),
        _buildRow(userEntry, tab, valueColor),
      ],
    );
  }
}
