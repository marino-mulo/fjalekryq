import '../database_helper.dart';
import '../models/daily_puzzle_model.dart';
import 'base_repository.dart';

class DailyPuzzleRepository extends BaseRepository<DailyPuzzleModel> {
  DailyPuzzleRepository(DatabaseHelper dbHelper) : super(dbHelper, 'daily_puzzle');

  @override
  DailyPuzzleModel fromMap(Map<String, dynamic> map) => DailyPuzzleModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(DailyPuzzleModel model) => model.toMap();

  /// Get a daily puzzle for a specific user and date.
  Future<DailyPuzzleModel?> getByUserAndDate(int userId, String date) =>
      _readRow(userId, date);

  /// Direct SQLite lookup — bypasses any subclass override.
  /// Used by [upsert] to avoid virtual-dispatch recursion when a
  /// hybrid subclass calls `super.upsert` as a write-through from
  /// its overridden `getByUserAndDate`.
  Future<DailyPuzzleModel?> _readRow(int userId, String date) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'daily_puzzle',
      where: 'user_id = ? AND date = ? AND invalidated = ?',
      whereArgs: [userId, date, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyPuzzleModel.fromMap(rows.first);
  }

  /// Insert or update a daily puzzle for a user+date.
  Future<void> upsert(
    int userId,
    String date, {
    String? puzzleJson,
    String? gridJson,
    bool? solved,
    int? swapsUsed,
    int? hintCount,
    int? totalSwapCount,
  }) async {
    final existing = await _readRow(userId, date);
    if (existing != null) {
      if (puzzleJson != null) existing.puzzleJson = puzzleJson;
      if (gridJson != null) existing.gridJson = gridJson;
      if (solved != null) existing.solved = solved ? 1 : 0;
      if (swapsUsed != null) existing.swapsUsed = swapsUsed;
      if (hintCount != null) existing.hintCount = hintCount;
      if (totalSwapCount != null) existing.totalSwapCount = totalSwapCount;
      await update(existing.id!, existing);
    } else {
      final model = DailyPuzzleModel(
        userId: userId,
        date: date,
        puzzleJson: puzzleJson ?? '',
        gridJson: gridJson,
        solved: (solved ?? false) ? 1 : 0,
        swapsUsed: swapsUsed ?? 0,
        hintCount: hintCount ?? 0,
        totalSwapCount: totalSwapCount ?? 0,
      );
      await insert(model);
    }
  }

  /// Get today's puzzle for a user.
  Future<DailyPuzzleModel?> getTodayPuzzle(int userId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return getByUserAndDate(userId, today);
  }
}
