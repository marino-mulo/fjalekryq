import '../database_helper.dart';
import '../models/notification_model.dart';
import 'base_repository.dart';

class NotificationRepository extends BaseRepository<NotificationModel> {
  NotificationRepository(DatabaseHelper dbHelper) : super(dbHelper, 'notifications');

  @override
  NotificationModel fromMap(Map<String, dynamic> map) => NotificationModel.fromMap(map);
  @override
  Map<String, dynamic> toMap(NotificationModel model) => model.toMap();

  /// Get unread notifications for a user.
  Future<List<NotificationModel>> getUnread(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'notifications',
      where: 'user_id = ? AND opened = 0 AND invalidated = ?',
      whereArgs: [userId, DatabaseHelper.statusActive],
      orderBy: 'created_at DESC',
    );
    return rows.map(fromMap).toList();
  }

  /// Mark a notification as read.
  Future<void> markAsRead(int id) async {
    final db = await dbHelper.database;
    await db.update(
      'notifications',
      {'opened': 1, 'modified_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get unread count.
  Future<int> getUnreadCount(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM notifications '
      'WHERE user_id = ? AND opened = 0 AND invalidated = ?',
      [userId, DatabaseHelper.statusActive],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }
}
