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
  Future<void> upsert(int userId, int level, {bool? completed}) async {
    await super.upsert(userId, level, completed: completed);
    if (completed == true) {
      try {
        await _remote.upsert(userId, level, completed: completed);
      } catch (_) {}
    }
  }
}
