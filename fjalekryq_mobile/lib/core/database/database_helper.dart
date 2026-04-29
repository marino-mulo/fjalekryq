import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config/app_config.dart';

/// Central SQLite database helper for Fjalëkryq.
/// Manages creation and migration of all 9 tables with audit columns.
///
/// Audit columns on every table:
///   created_at, created_by, created_ip,
///   modified_at, modified_by, modified_ip,
///   invalidated (20 = active, 10 = soft-deleted)
class DatabaseHelper {
  static String get _databaseName => AppConfig.databaseName;
  static const _databaseVersion = 5;

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

    // ── 2. progress ─────────────────────────────────────────
    batch.execute('''
      CREATE TABLE progress (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER NOT NULL,
        level         INTEGER NOT NULL,
        completed     INTEGER NOT NULL DEFAULT 0,
        moves_left    INTEGER,
        $_auditColumns,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_progress_user ON progress(user_id, level) WHERE invalidated = $statusActive',
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

    // ── 12. level_patterns (rotating difficulty cycle) ─────
    batch.execute('''
      CREATE TABLE level_patterns (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        slot_index  INTEGER NOT NULL,
        difficulty  TEXT    NOT NULL
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX ix_level_patterns_slot ON level_patterns(slot_index)',
    );
    for (final entry in _levelPatternSeed) {
      batch.insert('level_patterns', {
        'slot_index': entry.$1,
        'difficulty': entry.$2,
      });
    }

    // ── 13. user_generated_levels (per-user puzzle cache) ──
    batch.execute('''
      CREATE TABLE user_generated_levels (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id      INTEGER NOT NULL,
        level        INTEGER NOT NULL,
        difficulty   TEXT    NOT NULL,
        puzzle_json  TEXT    NOT NULL,
        created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX ix_user_generated_levels_user_level '
      'ON user_generated_levels(user_id, level)',
    );

    await batch.commit(noResult: true);
  }

  /// Seed data for `level_patterns`. Level N uses slot ((N - 1) % 5).
  static const List<(int, String)> _levelPatternSeed = [
    (0, 'Medium'),
    (1, 'Medium'),
    (2, 'Hard'),
    (3, 'Easy'),
    (4, 'Medium'),
  ];

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

    if (oldVersion < 4) {
      await _upgradeTo4(db);
    }
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS coins');
    }
  }

  /// Server-driven levels migration.
  ///
  /// Wrapped in a transaction so either every step lands or none do.
  /// Each step is idempotent — re-running is safe even if the previous
  /// run partially applied the schema before crashing.
  Future<void> _upgradeTo4(Database db) async {
    await db.transaction((txn) async {
      // Step 1. Remap `invalidated` values: 0 → 20 (active), 1 → 10 (deleted).
      // The app already uses 20/10 for new rows, but old installs may still
      // carry the 0/1 convention. Apply to every client-side table that has
      // the column (mapping from the task's logical names to our names:
      // user_coins → coins, user_streaks → daily_streak,
      // user_progress → progress, user_daily_progress → daily_puzzle).
      const remapTables = [
        'users',
        'daily_streak',
        'progress',
        'daily_puzzle',
      ];
      for (final t in remapTables) {
        if (!await _tableExists(txn, t)) continue;
        await txn.update(t, {'invalidated': statusActive},
            where: 'invalidated = 0');
        await txn.update(t, {'invalidated': statusDeleted},
            where: 'invalidated = 1');
      }

      // Step 2. Drop `stars` from `user_progress` if present. Our local
      // `progress` table never had a `stars` column — skip silently.

      // Step 3. Drop the bundled-levels table. The server now generates
      // every level on demand, so the seeded puzzles are obsolete.
      await txn.execute('DROP TABLE IF EXISTS level');

      // Step 4. No app_config / max_level / level_cap table exists locally.

      // Step 5. No level_rewards table exists locally.

      // Step 6. Create `level_patterns` + seed the rotating cycle. Use
      // IF NOT EXISTS + INSERT OR IGNORE so re-running is a no-op.
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS level_patterns (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          slot_index  INTEGER NOT NULL,
          difficulty  TEXT    NOT NULL
        )
      ''');
      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ix_level_patterns_slot '
        'ON level_patterns(slot_index)',
      );
      for (final entry in _levelPatternSeed) {
        await txn.rawInsert(
          'INSERT OR IGNORE INTO level_patterns (slot_index, difficulty) '
          'VALUES (?, ?)',
          [entry.$1, entry.$2],
        );
      }

      // Step 7. Create `user_generated_levels` puzzle cache.
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS user_generated_levels (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id      INTEGER NOT NULL,
          level        INTEGER NOT NULL,
          difficulty   TEXT    NOT NULL,
          puzzle_json  TEXT    NOT NULL,
          created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ix_user_generated_levels_user_level '
        'ON user_generated_levels(user_id, level)',
      );

      // Step 8. Add `moves_left` to `progress` if missing. SQLite lacks
      // `ADD COLUMN IF NOT EXISTS`, so check PRAGMA first.
      if (!await _columnExists(txn, 'progress', 'moves_left')) {
        await txn.execute(
          'ALTER TABLE progress ADD COLUMN moves_left INTEGER',
        );
      }

      // Step 9. No pending-sync queue table exists locally.
    });
  }

  static Future<bool> _tableExists(
    DatabaseExecutor db,
    String name,
  ) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [name],
    );
    return rows.isNotEmpty;
  }

  static Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((r) => r['name'] == column);
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
