import '../database/repositories/progress_repository.dart';
import 'remote_progress_repository.dart';

/// Hybrid: writes go to local SQLite first (source of truth for UI) and
/// then best-effort to the server so the leaderboard / cross-device
/// progress stays in sync. Reads stay local — the game screen needs
/// instant answers and the server has no richer data to offer here.
///
/// Extends [ProgressRepository] so it's accepted anywhere the concrete
/// local type is already injected — no service-layer changes required.
class HybridProgressRepository extends ProgressRepository {
  final RemoteProgressRepository _remote;

  HybridProgressRepository(super.dbHelper, this._remote);

  @override
  Future<void> upsert(
    int userId,
    int level, {
    bool? completed,
    int? movesLeft,
  }) async {
    await super.upsert(userId, level, completed: completed, movesLeft: movesLeft);
    if (completed == true) {
      try {
        await _remote.upsert(
          userId,
          level,
          completed: completed,
          movesLeft: movesLeft ?? 0,
        );
      } catch (_) {}
    }
  }

  /// Writes locally, then calls the server so the authoritative coin
  /// reward and new balance can be surfaced in the win modal.
  @override
  Future<LevelCompletionResult?> completeLevel(
    int userId,
    int level, {
    required int movesLeft,
  }) async {
    await super.upsert(userId, level, completed: true);
    try {
      return await _remote.upsert(
        userId,
        level,
        completed: true,
        movesLeft: movesLeft,
      );
    } catch (_) {
      return null;
    }
  }
}
