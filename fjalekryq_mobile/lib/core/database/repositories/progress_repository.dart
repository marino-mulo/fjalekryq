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

  /// Sum all stars for a user.
  Future<int> getTotalStars(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(stars), 0) as total FROM progress '
      'WHERE user_id = ? AND invalidated = ?',
      [userId, DatabaseHelper.statusActive],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Upsert progress: update if exists, insert if not.
  Future<void> upsert(int userId, int level, {int? stars, bool? completed}) async {
    final existing = await getByUserAndLevel(userId, level);
    if (existing != null) {
      if (stars != null) existing.stars = stars;
      if (completed != null) existing.completed = completed ? 1 : 0;
      await update(existing.id!, existing);
    } else {
      final model = ProgressModel(
        userId: userId,
        level: level,
        stars: stars ?? 0,
        completed: (completed ?? false) ? 1 : 0,
      );
      await insert(model);
    }
  }
}
