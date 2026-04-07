import '../database_helper.dart';
import '../models/level_model.dart';
import 'base_repository.dart';

class LevelRepository extends BaseRepository<LevelModel> {
  LevelRepository(DatabaseHelper dbHelper) : super(dbHelper, 'level');

  @override
  LevelModel fromMap(Map<String, dynamic> map) => LevelModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(LevelModel model) => model.toMap();

  /// Get level config by level number.
  Future<LevelModel?> getByLevel(int level) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'level',
      where: 'level = ? AND invalidated = ?',
      whereArgs: [level, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LevelModel.fromMap(rows.first);
  }
}
