import 'dart:math';
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

  /// Get or create a local guest user with a random guest_xxxx tag.
  /// This guest is device-bound (no account, no sync).
  Future<UserModel> getOrCreateLocalUser() async {
    // Check for any existing active user on this device
    final db = await dbHelper.database;
    final rows = await db.query(
      'users',
      where: 'invalidated = ?',
      whereArgs: [DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isNotEmpty) return UserModel.fromMap(rows.first);

    // Create guest with random 7-digit tag
    final tag = (Random().nextInt(9000000) + 1000000).toString();
    final user = UserModel(username: 'guest_$tag');
    final id = await insert(user);
    user.id = id;
    return user;
  }

  /// Check if a username is already taken by another user.
  Future<bool> isUsernameTaken(String username, int excludeUserId) async {
    final existing = await getByUsername(username);
    if (existing == null) return false;
    return existing.id != excludeUserId;
  }

  /// Update nickname (display name).
  Future<void> updateNickname(int userId, String nickname) async {
    final user = await getById(userId);
    if (user == null) return;
    user.username = nickname;
    await update(userId, user);
  }

  /// Update avatar path/identifier.
  Future<void> updateAvatar(int userId, String avatar) async {
    final user = await getById(userId);
    if (user == null) return;
    user.avatar = avatar;
    await update(userId, user);
  }
}
