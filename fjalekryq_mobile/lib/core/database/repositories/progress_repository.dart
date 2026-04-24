import '../../network/remote_progress_repository.dart';
import '../database_helper.dart';
import '../models/progress_model.dart';
import 'base_repository.dart';

class ProgressRepository extends BaseRepository<ProgressModel> {
  ProgressRepository(DatabaseHelper dbHelper) : super(dbHelper, 'progress');

  @override
  ProgressModel fromMap(Map<String, dynamic> map) => ProgressModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(ProgressModel model) => model.toMap();

  /// Get progress for a specific user and level.
  Future<ProgressModel?> getByUserAndLevel(int userId, int level) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'progress',
      where: 'user_id = ? AND level = ? AND invalidated = ?',
      whereArgs: [userId, level, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProgressModel.fromMap(rows.first);
  }

  /// Get the highest completed level for a user.
  Future<int> getHighestCompletedLevel(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT MAX(level) as max_level FROM progress '
      'WHERE user_id = ? AND completed = 1 AND invalidated = ?',
      [userId, DatabaseHelper.statusActive],
    );
    return (rows.first['max_level'] as int?) ?? 0;
  }

  /// Count total completed levels for a user.
  Future<int> getCompletedCount(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM progress '
      'WHERE user_id = ? AND completed = 1 AND invalidated = ?',
      [userId, DatabaseHelper.statusActive],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  /// Upsert progress: update if exists, insert if not.
  /// [movesLeft] is accepted for signature parity with the hybrid/remote
  /// repos, which forward it to the server for coin rewards. The local
  /// repo doesn't need it.
  Future<void> upsert(
    int userId,
    int level, {
    bool? completed,
    int movesLeft = 0,
  }) async {
    final existing = await getByUserAndLevel(userId, level);
    if (existing != null) {
      if (completed != null) existing.completed = completed ? 1 : 0;
      await update(existing.id!, existing);
    } else {
      final model = ProgressModel(
        userId: userId,
        level: level,
        completed: (completed ?? false) ? 1 : 0,
      );
      await insert(model);
    }
  }

  /// Mark [level] complete locally and report the server's coin reward
  /// back to the caller. The base local implementation has nothing to
  /// report — the hybrid repo overrides this to actually hit the API.
  Future<LevelCompletionResult?> completeLevel(
    int userId,
    int level, {
    required int movesLeft,
  }) async {
    await upsert(userId, level, completed: true, movesLeft: movesLeft);
    return null;
  }
}
