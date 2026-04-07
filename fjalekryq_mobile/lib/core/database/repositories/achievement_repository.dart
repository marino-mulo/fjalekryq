import '../database_helper.dart';
import '../models/achievement_model.dart';
import 'base_repository.dart';

class AchievementRepository extends BaseRepository<AchievementModel> {
  AchievementRepository(DatabaseHelper dbHelper) : super(dbHelper, 'achievements');

  @override
  AchievementModel fromMap(Map<String, dynamic> map) => AchievementModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(AchievementModel model) => model.toMap();

  /// Check if a user has unlocked a specific achievement.
  Future<bool> hasAchievement(int userId, String achievementId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'achievements',
      where: 'user_id = ? AND achievement_id = ? AND invalidated = ?',
      whereArgs: [userId, achievementId, DatabaseHelper.statusActive],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Unlock an achievement (no-op if already unlocked).
  Future<void> unlock(int userId, String achievementId) async {
    if (await hasAchievement(userId, achievementId)) return;
    final model = AchievementModel(
      userId: userId,
      achievementId: achievementId,
      unlockedAt: DateTime.now().toIso8601String(),
    );
    await insert(model);
  }
}
