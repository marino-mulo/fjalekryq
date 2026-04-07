import '../database_helper.dart';
import '../models/settings_model.dart';
import 'base_repository.dart';

class SettingsRepository extends BaseRepository<SettingsModel> {
  SettingsRepository(DatabaseHelper dbHelper) : super(dbHelper, 'settings');

  @override
  SettingsModel fromMap(Map<String, dynamic> map) => SettingsModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(SettingsModel model) => model.toMap();

  /// Get settings for a user.
  Future<SettingsModel?> getByUser(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'settings',
      where: 'user_id = ? AND invalidated = ?',
      whereArgs: [userId, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SettingsModel.fromMap(rows.first);
  }

  /// Get or create default settings for a user.
  Future<SettingsModel> getOrCreate(int userId) async {
    final existing = await getByUser(userId);
    if (existing != null) return existing;
    final model = SettingsModel(userId: userId);
    final id = await insert(model);
    model.id = id;
    return model;
  }

  /// Save all settings at once.
  Future<void> saveSettings(SettingsModel settings) async {
    await update(settings.id!, settings);
  }
}
