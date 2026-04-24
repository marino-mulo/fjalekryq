import '../database/models/progress_model.dart';
import 'api_client.dart';

/// Server's response for a level-completion call.
class LevelCompletionResult {
  final int level;
  final int coinsAwarded;
  final int newBalance;

  const LevelCompletionResult({
    required this.level,
    required this.coinsAwarded,
    required this.newBalance,
  });
}

/// Remote implementation mirroring [ProgressRepository]'s public interface.
class RemoteProgressRepository {
  Future<ProgressModel?> getByUserAndLevel(int userId, int level) async {
    final data = await ApiClient.get('/progress');
    final levels = (data['levels'] as List<dynamic>? ?? []);
    final match = levels.cast<Map<String, dynamic>>()
        .where((l) => (l['level'] as int?) == level)
        .firstOrNull;
    if (match == null) return null;
    return ProgressModel(
      userId:    userId,
      level:     match['level']     as int,
      completed: (match['completed'] as bool? ?? false) ? 1 : 0,
    );
  }

  Future<int> getHighestCompletedLevel(int userId) async {
    final data = await ApiClient.get('/progress');
    return (data['highestCompletedLevel'] as int?) ?? 0;
  }

  Future<int> getCompletedCount(int userId) async {
    final data = await ApiClient.get('/progress');
    final levels = (data['levels'] as List<dynamic>? ?? []);
    return levels.cast<Map<String, dynamic>>()
        .where((l) => l['completed'] == true)
        .length;
  }

  /// Mark [level] cleared. Server requires `movesLeft` and returns the
  /// coin reward + new balance so the client can show the authoritative
  /// numbers without duplicating the reward math.
  Future<LevelCompletionResult?> upsert(
    int userId,
    int level, {
    bool? completed,
    int movesLeft = 0,
  }) async {
    if (completed != true) return null;
    final data = await ApiClient.post(
      '/progress/$level',
      body: {'movesLeft': movesLeft < 0 ? 0 : movesLeft},
    );
    return LevelCompletionResult(
      level:        data['level']        as int,
      coinsAwarded: data['coinsAwarded'] as int,
      newBalance:   data['newBalance']   as int,
    );
  }
}
