import '../database_helper.dart';
import '../models/ad_reward_model.dart';
import 'base_repository.dart';

class AdRewardRepository extends BaseRepository<AdRewardModel> {
  AdRewardRepository(DatabaseHelper dbHelper) : super(dbHelper, 'ad_rewards');

  @override
  AdRewardModel fromMap(Map<String, dynamic> map) => AdRewardModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(AdRewardModel model) => model.toMap();

  /// Claim an ad reward.
  Future<int> claim(int userId, String type) async {
    final model = AdRewardModel(
      userId: userId,
      type: type,
      claimedAt: DateTime.now().toIso8601String(),
    );
    return insert(model);
  }

  /// Get rewards claimed today by type.
  Future<int> claimedTodayCount(int userId, String type) async {
    final db = await dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ad_rewards '
      'WHERE user_id = ? AND type = ? AND claimed_at LIKE ? AND invalidated = ?',
      [userId, type, '$today%', DatabaseHelper.statusActive],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }
}
