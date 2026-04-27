import '../database_helper.dart';
import '../models/daily_streak_model.dart';
import 'base_repository.dart';

class DailyStreakRepository extends BaseRepository<DailyStreakModel> {
  DailyStreakRepository(DatabaseHelper dbHelper) : super(dbHelper, 'daily_streak');

  @override
  DailyStreakModel fromMap(Map<String, dynamic> map) => DailyStreakModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(DailyStreakModel model) => model.toMap();

  /// Get streak record for a user.
  Future<DailyStreakModel?> getByUser(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'daily_streak',
      where: 'user_id = ? AND invalidated = ?',
      whereArgs: [userId, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyStreakModel.fromMap(rows.first);
  }

  /// Get existing streak or create a new one for the user.
  Future<DailyStreakModel> getOrCreate(int userId) => _readOrCreateLocal(userId);

  /// Direct SQLite read-or-create — bypasses any subclass override.
  /// Used by [updateStreak] and [setFrozenUntil] to avoid virtual-dispatch
  /// recursion when a hybrid subclass's `getOrCreate` triggers a
  /// write-through that calls back into `super.updateStreak`.
  Future<DailyStreakModel> _readOrCreateLocal(int userId) async {
    final existing = await getByUser(userId);
    if (existing != null) return existing;

    final model = DailyStreakModel(userId: userId);
    final id = await insert(model);
    model.id = id;
    return model;
  }

  /// Update streak values for a user.
  Future<void> updateStreak(
    int userId, {
    required int currentStreak,
    required int bestStreak,
    required String lastSolvedDate,
  }) async {
    final streak = await _readOrCreateLocal(userId);
    streak.currentStreak = currentStreak;
    streak.bestStreak = bestStreak;
    streak.lastSolvedDate = lastSolvedDate;
    await update(streak.id!, streak);
  }

  /// Set the frozen-until date for streak protection.
  Future<void> setFrozenUntil(int userId, String date) async {
    final streak = await _readOrCreateLocal(userId);
    streak.frozenUntil = date;
    await update(streak.id!, streak);
  }

  /// Get top 20 users by best streak, joined with users table.
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final db = await dbHelper.database;
    return db.rawQuery('''
      SELECT
        ds.user_id,
        ds.current_streak,
        ds.best_streak,
        ds.last_solved_date,
        u.username,
        u.avatar
      FROM daily_streak ds
      INNER JOIN users u ON u.id = ds.user_id AND u.invalidated = ?
      WHERE ds.invalidated = ?
      ORDER BY ds.best_streak DESC, ds.current_streak DESC
      LIMIT 20
    ''', [DatabaseHelper.statusActive, DatabaseHelper.statusActive]);
  }
}
