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
  Future<void> upsert(int userId, int level, {int? stars, bool? completed}) async {
    // Local first — always succeeds, drives the UI.
    await super.upsert(userId, level, stars: stars, completed: completed);

    // Best-effort remote sync. Only fires on completion because the
    // server's `user_progress` only cares about finished levels (used
    // by the leaderboard). In-progress updates stay local.
    if (completed == true) {
      try {
        await _remote.upsert(userId, level, stars: stars, completed: completed);
      } catch (_) {
        // Offline / auth / transient server error — the next win retries.
      }
    }
  }
}
