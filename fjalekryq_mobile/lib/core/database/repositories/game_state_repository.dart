import '../database_helper.dart';
import '../models/game_state_model.dart';
import 'base_repository.dart';

class GameStateRepository extends BaseRepository<GameStateModel> {
  GameStateRepository(DatabaseHelper dbHelper) : super(dbHelper, 'game_state');

  @override
  GameStateModel fromMap(Map<String, dynamic> map) => GameStateModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(GameStateModel model) => model.toMap();

  /// Get saved game state for a user and level.
  Future<GameStateModel?> getByUserAndLevel(int userId, int level) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'game_state',
      where: 'user_id = ? AND level = ? AND invalidated = ?',
      whereArgs: [userId, level, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GameStateModel.fromMap(rows.first);
  }

  /// Save or update game state for a user+level.
  Future<void> upsert(GameStateModel state) async {
    final existing = await getByUserAndLevel(state.userId, state.level);
    if (existing != null) {
      await update(existing.id!, state);
    } else {
      await insert(state);
    }
  }

  /// Clear saved game state for a user+level.
  Future<void> clearState(int userId, int level) async {
    final existing = await getByUserAndLevel(userId, level);
    if (existing != null) {
      await softDelete(existing.id!);
    }
  }
}
