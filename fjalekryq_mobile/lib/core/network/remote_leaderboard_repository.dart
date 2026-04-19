import 'api_client.dart';

class LeaderboardEntry {
  final int     rank;
  final int     userId;
  final String  username;
  final String? avatar;
  final int     score;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    this.avatar,
    required this.score,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) => LeaderboardEntry(
    rank:     m['rank']     as int,
    userId:   m['userId']   as int,
    username: m['username'] as String,
    avatar:   m['avatar']   as String?,
    score:    m['score']    as int,
  );
}

/// Fetches leaderboard data from the server. No local fallback needed —
/// leaderboard is only available when online.
class RemoteLeaderboardRepository {
  Future<List<LeaderboardEntry>> getByLevel() async =>
      _parse(await ApiClient.getList('/leaderboard/level'));

  Future<List<LeaderboardEntry>> getByStars() async =>
      _parse(await ApiClient.getList('/leaderboard/stars'));

  Future<List<LeaderboardEntry>> getByStreak() async =>
      _parse(await ApiClient.getList('/leaderboard/streak'));

  static List<LeaderboardEntry> _parse(List<dynamic> list) =>
      list.cast<Map<String, dynamic>>()
          .map(LeaderboardEntry.fromMap)
          .toList();
}
