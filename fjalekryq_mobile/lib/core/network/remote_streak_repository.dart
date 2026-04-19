import '../database/models/daily_streak_model.dart';
import 'api_client.dart';

/// Remote implementation mirroring [DailyStreakRepository]'s public interface.
class RemoteStreakRepository {
  Future<DailyStreakModel> getOrCreate(int userId) async {
    final data = await ApiClient.get('/streak');
    return _fromMap(userId, data);
  }

  Future<DailyStreakModel?> getByUser(int userId) async {
    try {
      final data = await ApiClient.get('/streak');
      return _fromMap(userId, data);
    } catch (_) {
      rethrow;
    }
  }

  /// Streak is updated server-side when POST /daily/solved is called.
  /// This method is a no-op for the remote repo; the server is authoritative.
  Future<void> updateStreak(
    int userId, {
    required int    currentStreak,
    required int    bestStreak,
    required String lastSolvedDate,
  }) async {
    // No-op: server updates streak automatically on daily/solved.
  }

  /// Posts streak recovery to the server.
  Future<void> setFrozenUntil(int userId, String date) async {
    await ApiClient.postVoid('/streak/recover');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static DailyStreakModel _fromMap(int userId, Map<String, dynamic> data) =>
      DailyStreakModel(
        userId:          userId,
        currentStreak:   data['currentStreak']  as int? ?? 0,
        bestStreak:      data['bestStreak']      as int? ?? 0,
        lastSolvedDate:  data['lastSolvedDate']  as String?,
        frozenUntil:     data['frozenUntil']     as String?,
      );
}
