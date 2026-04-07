import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Base repository with shared CRUD operations and soft-delete support.
abstract class BaseRepository<T> {
  final DatabaseHelper dbHelper;
  final String tableName;

  BaseRepository(this.dbHelper, this.tableName);

  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T model);

  Future<Database> get _db => dbHelper.database;

  /// Insert a new record. Returns the inserted row id.
  Future<int> insert(T model) async {
    final db = await _db;
    final map = toMap(model);
    map.remove('id');
    final now = DateTime.now().toIso8601String();
    map['created_at'] = now;
    map['modified_at'] = now;
    map['invalidated'] = DatabaseHelper.statusActive;
    return db.insert(tableName, map);
  }

  /// Update an existing record by id.
  Future<int> update(int id, T model) async {
    final db = await _db;
    final map = toMap(model);
    map.remove('id');
    map['modified_at'] = DateTime.now().toIso8601String();
    return db.update(tableName, map, where: 'id = ?', whereArgs: [id]);
  }

  /// Soft-delete: set invalidated = 10.
  Future<int> softDelete(int id) async {
    final db = await _db;
    return db.update(
      tableName,
      {
        'invalidated': DatabaseHelper.statusDeleted,
        'modified_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard-delete (use sparingly).
  Future<int> hardDelete(int id) async {
    final db = await _db;
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Get a single active record by id.
  Future<T?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      tableName,
      where: 'id = ? AND invalidated = ?',
      whereArgs: [id, DatabaseHelper.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return fromMap(rows.first);
  }

  /// Get all active records.
  Future<List<T>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      tableName,
      where: 'invalidated = ?',
      whereArgs: [DatabaseHelper.statusActive],
    );
    return rows.map(fromMap).toList();
  }

  /// Get all active records for a given user.
  Future<List<T>> getByUserId(int userId) async {
    final db = await _db;
    final rows = await db.query(
      tableName,
      where: 'user_id = ? AND invalidated = ?',
      whereArgs: [userId, DatabaseHelper.statusActive],
    );
    return rows.map(fromMap).toList();
  }

  /// Run a custom query and return mapped models.
  Future<List<T>> rawQuery(String sql, [List<Object?>? args]) async {
    final db = await _db;
    final rows = await db.rawQuery(sql, args);
    return rows.map(fromMap).toList();
  }
}
