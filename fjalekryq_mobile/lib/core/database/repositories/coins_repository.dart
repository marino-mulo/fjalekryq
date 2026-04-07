import '../database_helper.dart';
import '../models/coins_model.dart';
import 'base_repository.dart';

class CoinsRepository extends BaseRepository<CoinsModel> {
  CoinsRepository(DatabaseHelper dbHelper) : super(dbHelper, 'coins');

  @override
  CoinsModel fromMap(Map<String, dynamic> map) => CoinsModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(CoinsModel model) => model.toMap();

  /// Get coin record for a user.
  Future<CoinsModel?> getByUser(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'coins',
      where: 'user_id = ? AND invalidated = ?',
      whereArgs: [userId, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CoinsModel.fromMap(rows.first);
  }

  /// Get or create coins for a user (starting balance = 100).
  Future<CoinsModel> getOrCreate(int userId) async {
    final existing = await getByUser(userId);
    if (existing != null) return existing;
    final model = CoinsModel(userId: userId, balance: 100);
    final id = await insert(model);
    model.id = id;
    return model;
  }

  /// Update the balance directly.
  Future<void> updateBalance(int userId, int newBalance) async {
    final coins = await getOrCreate(userId);
    coins.balance = newBalance;
    await update(coins.id!, coins);
  }

  /// Update daily claim info.
  Future<void> updateDailyClaim(int userId, String claimDate, int streakDay, int newBalance) async {
    final coins = await getOrCreate(userId);
    coins.lastDailyClaim = claimDate;
    coins.streakDay = streakDay;
    coins.balance = newBalance;
    await update(coins.id!, coins);
  }
}
