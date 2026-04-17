import 'package:flutter/material.dart';
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
