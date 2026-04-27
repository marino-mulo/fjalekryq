import '../database_helper.dart';
import '../models/user_generated_level_model.dart';

/// Per-user cache of server-generated puzzles, read when offline so the
/// user can keep replaying levels they've already fetched. The server
/// stays the source of truth; cache entries are evicted once the level
/// is cleared (see [deleteByUserAndLevel]).
class UserGeneratedLevelRepository {
  final DatabaseHelper dbHelper;

  UserGeneratedLevelRepository(this.dbHelper);

  static const _table = 'user_generated_levels';

  Future<UserGeneratedLevelModel?> getByUserAndLevel(
    int userId,
    int level,
  ) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      _table,
      where: 'user_id = ? AND level = ?',
      whereArgs: [userId, level],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserGeneratedLevelModel.fromMap(rows.first);
  }

  /// Insert or replace the cached puzzle for [userId] / [level].
  Future<void> upsert(UserGeneratedLevelModel model) async {
    final db = await dbHelper.database;
    final existing = await getByUserAndLevel(model.userId, model.level);
    final map = model.toMap();
    if (existing != null) {
      await db.update(
        _table,
        map,
        where: 'user_id = ? AND level = ?',
        whereArgs: [model.userId, model.level],
      );
    } else {
      await db.insert(_table, map);
    }
  }

  /// Return cached puzzles for [userId] whose level falls within
  /// `[fromLevel, toLevel]` inclusive. Used by the offline generator's
  /// word-exclusion lookback (same behaviour as the server's
  /// `IUserGeneratedLevelRepository.ListRangeAsync`).
  Future<List<UserGeneratedLevelModel>> listRange(
    int userId,
    int fromLevel,
    int toLevel,
  ) async {
    if (toLevel < fromLevel) return const [];
    final db = await dbHelper.database;
    final rows = await db.query(
      _table,
      where: 'user_id = ? AND level BETWEEN ? AND ?',
      whereArgs: [userId, fromLevel, toLevel],
    );
    return rows.map(UserGeneratedLevelModel.fromMap).toList();
  }

  Future<void> deleteByUserAndLevel(int userId, int level) async {
    final db = await dbHelper.database;
    await db.delete(
      _table,
      where: 'user_id = ? AND level = ?',
      whereArgs: [userId, level],
    );
  }
}
