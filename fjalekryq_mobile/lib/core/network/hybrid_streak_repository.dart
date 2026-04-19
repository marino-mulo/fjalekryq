import '../database/models/daily_streak_model.dart';
import '../database/repositories/daily_streak_repository.dart';
import 'remote_streak_repository.dart';

/// Hybrid streak repo: reads from remote (authoritative) or falls back to
/// local SQLite. Writes to local first; remote update happens on solve.
class HybridStreakRepository extends DailyStreakRepository {
  final RemoteStreakRepository _remote;

  HybridStreakRepository(super.dbHelper, this._remote);

  @override
  Future<DailyStreakModel> getOrCreate(int userId) async {
    try {
      final remoteModel = await _remote.getOrCreate(userId);
      // Write-through
      await _syncToLocal(userId, remoteModel);
      return remoteModel;
    } catch (_) {
      // Fall back to local
    }
    return super.getOrCreate(userId);
  }

  @override
  Future<void> updateStreak(
    int userId, {
    required int    currentStreak,
    required int    bestStreak,
    required String lastSolvedDate,
  }) async {
    // Update local immediately
    await super.updateStreak(
      userId,
      currentStreak:  currentStreak,
      bestStreak:     bestStreak,
      lastSolvedDate: lastSolvedDate,
    );
    // Remote streak is updated server-side via POST /daily/solved
  }

  @override
  Future<void> setFrozenUntil(int userId, String date) async {
    await super.setFrozenUntil(userId, date);
    try {
      await _remote.setFrozenUntil(userId, date);
    } catch (_) {
      // streak recovery will be re-tried next session
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _syncToLocal(int userId, DailyStreakModel remote) async {
    final local = await super.getOrCreate(userId);
    if (remote.currentStreak != local.currentStreak ||
        remote.bestStreak != local.bestStreak ||
        remote.lastSolvedDate != local.lastSolvedDate) {
      await super.updateStreak(
        userId,
        currentStreak:  remote.currentStreak,
        bestStreak:     remote.bestStreak,
        lastSolvedDate: remote.lastSolvedDate ?? local.lastSolvedDate ?? '',
      );
    }
  }
}
