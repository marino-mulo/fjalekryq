import '../database_helper.dart';
import '../models/user_model.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository<UserModel> {
  UserRepository(DatabaseHelper dbHelper) : super(dbHelper, 'users');

  @override
  UserModel fromMap(Map<String, dynamic> map) => UserModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(UserModel model) => model.toMap();

  /// Get user by username.
  Future<UserModel?> getByUsername(String username) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND invalidated = ?',
      whereArgs: [username, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  /// Get or create a local default user (for offline-first).
  Future<UserModel> getOrCreateLocalUser() async {
    final existing = await getByUsername('local_player');
    if (existing != null) return existing;
    final user = UserModel(username: 'local_player');
    final id = await insert(user);
    user.id = id;
    return user;
  }
}
