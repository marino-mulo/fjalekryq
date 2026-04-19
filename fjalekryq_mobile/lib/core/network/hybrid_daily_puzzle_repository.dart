import '../database/database_helper.dart';
import '../database/models/daily_puzzle_model.dart';
import '../database/repositories/daily_puzzle_repository.dart';
import 'remote_daily_puzzle_repository.dart';

/// Hybrid: tries the remote API first; on any network failure falls back to
/// the local SQLite cache. Writes go to both remote (best effort) and local.
///
/// Extends [DailyPuzzleRepository] so it is accepted anywhere the concrete
/// local type is expected — no service-layer changes required.
class HybridDailyPuzzleRepository extends DailyPuzzleRepository {
  final RemoteDailyPuzzleRepository _remote;

  HybridDailyPuzzleRepository(super.dbHelper, this._remote);

  @override
  Future<DailyPuzzleModel?> getByUserAndDate(int userId, String date) async {
    try {
      final remoteModel = await _remote.getByUserAndDate(userId, date);
      if (remoteModel != null) {
        // Write-through: keep local cache in sync
        await super.upsert(
          userId, date,
          puzzleJson:     remoteModel.puzzleJson,
          gridJson:       remoteModel.gridJson,
          solved:         remoteModel.solved == 1,
          swapsUsed:      remoteModel.swapsUsed,
          hintCount:      remoteModel.hintCount,
          totalSwapCount: remoteModel.totalSwapCount,
        );
        return remoteModel;
      }
    } catch (_) {
      // Network unavailable — fall through to local cache
    }
    return super.getByUserAndDate(userId, date);
  }

  @override
  Future<void> upsert(
    int userId,
    String date, {
    String? puzzleJson,
    String? gridJson,
    bool?   solved,
    int?    swapsUsed,
    int?    hintCount,
    int?    totalSwapCount,
  }) async {
    // Write to local first (always succeeds)
    await super.upsert(
      userId, date,
      puzzleJson:     puzzleJson,
      gridJson:       gridJson,
      solved:         solved,
      swapsUsed:      swapsUsed,
      hintCount:      hintCount,
      totalSwapCount: totalSwapCount,
    );

    // Best-effort remote sync (fire-and-forget on failure)
    try {
      await _remote.upsert(
        userId, date,
        puzzleJson:     puzzleJson,
        gridJson:       gridJson,
        solved:         solved,
        swapsUsed:      swapsUsed,
        hintCount:      hintCount,
        totalSwapCount: totalSwapCount,
      );
    } catch (_) {
      // Will sync on next successful network call
    }
  }
}
