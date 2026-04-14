import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Central SQLite database helper for Fjalëkryq.
/// Manages creation and migration of all 9 tables with audit columns.
///
/// Audit columns on every table:
///   created_at, created_by, created_ip,
///   modified_at, modified_by, modified_ip,
///   invalidated (20 = active, 10 = soft-deleted)
class DatabaseHelper {
  static const _databaseName = 'fjalekryq.db';
  static const _databaseVersion = 3;

  static const int statusActive = 20;
  static const int statusDeleted = 10;

  Database? _db;

  /// Open (and create if needed) the database.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Shared audit column SQL fragment used in every CREATE TABLE.
  static const String _auditColumns = '''
    created_at    TEXT NOT NULL DEFAULT (datetime('now')),
    created_by    TEXT,
    created_ip    TEXT,
    modified_at   TEXT NOT NULL DEFAULT (datetime('now')),
    modified_by   TEXT,
    modified_ip   TEXT,
    invalidated   INTEGER NOT NULL DEFAULT $statusActive
  ''';

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ── 1. users ────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT NOT NULL,
        email         TEXT,
        avatar        TEXT,
        $_auditColumns
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_users_username ON users(username) WHERE invalidated = $statusActive',
    );

    // ── 2. level ────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE level (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        level         INTEGER NOT NULL,
        difficulty    TEXT NOT NULL,
        coins_to_earn INTEGER NOT NULL DEFAULT 0,
        seed          INTEGER NOT NULL DEFAULT 0,
        $_auditColumns
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_level_level ON level(level) WHERE invalidated = $statusActive',
    );

    // ── 3. progress ─────────────────────────────────────────
    batch.execute('''
      CREATE TABLE progress (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER NOT NULL,
        level         INTEGER NOT NULL,
        stars         INTEGER NOT NULL DEFAULT 0,
        completed     INTEGER NOT NULL DEFAULT 0,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_progress_user ON progress(user_id, level) WHERE invalidated = $statusActive',
    );

    // ── 4. coins ────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE coins (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         INTEGER NOT NULL,
        balance         INTEGER NOT NULL DEFAULT 100,
        last_daily_claim TEXT,
        streak_day      INTEGER NOT NULL DEFAULT 0,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_coins_user ON coins(user_id) WHERE invalidated = $statusActive',
    );

    // ── 5. settings ─────────────────────────────────────────
    batch.execute('''
      CREATE TABLE settings (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id             INTEGER NOT NULL,
        music               INTEGER NOT NULL DEFAULT 1,
        sound               INTEGER NOT NULL DEFAULT 1,
        notification        INTEGER NOT NULL DEFAULT 1,
        email_notification  INTEGER NOT NULL DEFAULT 1,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_settings_user ON settings(user_id) WHERE invalidated = $statusActive',
    );

    // ── 6. notifications ────────────────────────────────────
    batch.execute('''
      CREATE TABLE notifications (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id           INTEGER NOT NULL,
        notification_text TEXT NOT NULL,
        opened            INTEGER NOT NULL DEFAULT 0,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_notifications_user ON notifications(user_id) WHERE invalidated = $statusActive',
    );

    // ── 7. game_state ───────────────────────────────────────
    batch.execute('''
      CREATE TABLE game_state (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         INTEGER NOT NULL,
        level           INTEGER NOT NULL,
        grid_json       TEXT NOT NULL,
        swaps_used      INTEGER NOT NULL DEFAULT 0,
        hint_cooldown   TEXT,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_game_state_user ON game_state(user_id, level) WHERE invalidated = $statusActive',
    );

    // ── 8. achievements ─────────────────────────────────────
    batch.execute('''
      CREATE TABLE achievements (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         INTEGER NOT NULL,
        achievement_id  TEXT NOT NULL,
        unlocked_at     TEXT,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_achievements_user ON achievements(user_id, achievement_id) WHERE invalidated = $statusActive',
    );

    // ── 9. ad_rewards ───────────────────────────────────────
    batch.execute('''
      CREATE TABLE ad_rewards (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        type        TEXT NOT NULL,
        claimed_at  TEXT,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_ad_rewards_user ON ad_rewards(user_id) WHERE invalidated = $statusActive',
    );

    // ── 10. daily_puzzle ────────────────────────────────────
    batch.execute('''
      CREATE TABLE daily_puzzle (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id           INTEGER NOT NULL,
        date              TEXT NOT NULL,
        puzzle_json       TEXT NOT NULL,
        grid_json         TEXT,
        solved            INTEGER NOT NULL DEFAULT 0,
        swaps_used        INTEGER NOT NULL DEFAULT 0,
        hint_count        INTEGER NOT NULL DEFAULT 0,
        total_swap_count  INTEGER NOT NULL DEFAULT 0,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_daily_puzzle_user_date ON daily_puzzle(user_id, date) WHERE invalidated = $statusActive',
    );

    // ── 11. daily_streak ──────────────────────────────────
    batch.execute('''
      CREATE TABLE daily_streak (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id           INTEGER NOT NULL,
        current_streak    INTEGER NOT NULL DEFAULT 0,
        best_streak       INTEGER NOT NULL DEFAULT 0,
        last_solved_date  TEXT,
        frozen_until      TEXT,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_daily_streak_user ON daily_streak(user_id) WHERE invalidated = $statusActive',
    );

    // ── Seed default level data ─────────────────────────────
    _seedLevels(batch);

    await batch.commit(noResult: true);
  }

  /// Seed the level table with the 10 active levels.
  void _seedLevels(Batch batch) {
    const levels = {
      1: ('easy',   20),
      2: ('easy',   20),
      3: ('easy',   20),
      4: ('medium', 35),
      5: ('medium', 35),
      6: ('medium', 35),
      7: ('hard',   50),
      8: ('hard',   50),
      9: ('hard',   50),
      10: ('expert', 80),
    };

    for (final entry in levels.entries) {
      final seed = entry.key * 99991 + 42013;
      batch.insert('level', {
        'level': entry.key,
        'difficulty': entry.value.$1,
        'coins_to_earn': entry.value.$2,
        'seed': seed,
        'invalidated': statusActive,
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add seed column to existing level rows
      await db.execute('ALTER TABLE level ADD COLUMN seed INTEGER NOT NULL DEFAULT 0');
      const seeds = {
        1: 1*99991+42013, 2: 2*99991+42013, 3: 3*99991+42013,
        4: 4*99991+42013, 5: 5*99991+42013, 6: 6*99991+42013,
        7: 7*99991+42013, 8: 8*99991+42013, 9: 9*99991+42013,
        10: 10*99991+42013,
      };
      for (final e in seeds.entries) {
        await db.update('level', {'seed': e.value}, where: 'level = ?', whereArgs: [e.key]);
      }
    }

    if (oldVersion < 3) {
      final batch = db.batch();

      batch.execute('''
        CREATE TABLE daily_puzzle (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id           INTEGER NOT NULL,
          date              TEXT NOT NULL,
          puzzle_json       TEXT NOT NULL,
          grid_json         TEXT,
          solved            INTEGER NOT NULL DEFAULT 0,
          swaps_used        INTEGER NOT NULL DEFAULT 0,
          hint_count        INTEGER NOT NULL DEFAULT 0,
          total_swap_count  INTEGER NOT NULL DEFAULT 0,
          created_at        TEXT NOT NULL DEFAULT (datetime('now')),
          created_by        TEXT,
          created_ip        TEXT,
          modified_at       TEXT NOT NULL DEFAULT (datetime('now')),
          modified_by       TEXT,
          modified_ip       TEXT,
          invalidated       INTEGER NOT NULL DEFAULT $statusActive,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');
      batch.execute(
        'CREATE UNIQUE INDEX idx_daily_puzzle_user_date ON daily_puzzle(user_id, date) WHERE invalidated = $statusActive',
      );

      batch.execute('''
        CREATE TABLE daily_streak (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id           INTEGER NOT NULL,
          current_streak    INTEGER NOT NULL DEFAULT 0,
          best_streak       INTEGER NOT NULL DEFAULT 0,
          last_solved_date  TEXT,
          frozen_until      TEXT,
          created_at        TEXT NOT NULL DEFAULT (datetime('now')),
          created_by        TEXT,
          created_ip        TEXT,
          modified_at       TEXT NOT NULL DEFAULT (datetime('now')),
          modified_by       TEXT,
          modified_ip       TEXT,
          invalidated       INTEGER NOT NULL DEFAULT $statusActive,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');
      batch.execute(
        'CREATE UNIQUE INDEX idx_daily_streak_user ON daily_streak(user_id) WHERE invalidated = $statusActive',
      );

      await batch.commit(noResult: true);
    }
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
