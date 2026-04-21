import 'package:flutter/material.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/network/api_client.dart';
import '../../core/network/remote_leaderboard_repository.dart' as remote;
import '../../core/services/connectivity_service.dart';
import '../../shared/constants/theme.dart';

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
  (color: Color(0xFF22C55E), icon: Icons.check_circle_rounded),       // 11 check
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
    case LeaderboardTab.streak: return mockStreakLeaderboard;
  }
}

Color valueColorForTab(LeaderboardTab tab) {
  switch (tab) {
    case LeaderboardTab.level:  return AppColors.cellGreen;
    case LeaderboardTab.streak: return const Color(0xFFFF6B35);
  }
}

// ─── Remote fetcher ───────────────────────────────────────────────────────────
// Loads leaderboard data from the API and adapts it to the UI's
// [LeaderboardEntry] model so the existing row/podium widgets keep working
// without any changes.

/// Outcome of a leaderboard load.
sealed class LeaderboardLoadResult {
  const LeaderboardLoadResult();
}

/// Success: API returned data.
class LeaderboardData extends LeaderboardLoadResult {
  final List<LeaderboardEntry> entries;
  const LeaderboardData(this.entries);
}

/// No internet connection — caller should render [OfflineView].
class LeaderboardOffline extends LeaderboardLoadResult {
  const LeaderboardOffline();
}

/// Request reached the network but failed (5xx, parse error, timeout after
/// the DNS check passed, etc.) — caller renders a generic error with retry.
class LeaderboardError extends LeaderboardLoadResult {
  final String message;
  const LeaderboardError(this.message);
}

/// Pulls the remote leaderboard for [tab] and converts rows to the UI
/// model. The "current user" row is marked by matching the logged-in
/// user's id from [AuthTokenStore].
Future<LeaderboardLoadResult> loadLeaderboard(LeaderboardTab tab) async {
  if (!await ConnectivityService.hasInternet()) {
    return const LeaderboardOffline();
  }

  try {
    final repo = remote.RemoteLeaderboardRepository();
    final apiEntries = switch (tab) {
      LeaderboardTab.level  => await repo.getByLevel(),
      LeaderboardTab.streak => await repo.getByStreak(),
    };

    final currentUserId = await AuthTokenStore.getUserId();

    final ui = apiEntries.map((e) => LeaderboardEntry(
          rank: e.rank,
          name: e.username,
          value: e.score,
          isCurrentUser: currentUserId != null && e.userId == currentUserId,
          avatarIndex: _avatarIndexFromString(e.avatar),
        )).toList();

    return LeaderboardData(ui);
  } on ApiException catch (_) {
    // Server replied with a non-2xx — treat as "try again later".
    return const LeaderboardError('Provoni përsëri më vonë.');
  } catch (_) {
    // Reaching here means connectivity said "online" but the actual
    // request still failed (API is down / unreachable / timed out).
    // Show the same "try again later" message so the user isn't told
    // they have no internet when they do.
    return const LeaderboardError('Provoni përsëri më vonë.');
  }
}

/// The backend stores `avatar` as a string. We treat it as an index into
/// [avatarOptions]; anything that doesn't parse cleanly falls through to
/// null (the UI then hashes the name for a stable avatar).
int? _avatarIndexFromString(String? raw) {
  if (raw == null) return null;
  final parsed = int.tryParse(raw);
  if (parsed == null) return null;
  return parsed.clamp(0, avatarOptions.length - 1);
}
