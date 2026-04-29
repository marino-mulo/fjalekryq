import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/models/user_generated_level_model.dart';
import '../database/repositories/user_generated_level_repository.dart';
import '../models/level_config.dart';
import '../models/puzzle.dart';
import 'puzzle_generator.dart';

/// Arguments shipped to the background isolate that runs
/// [PuzzleGenerator.generateRandom].
class _OfflineGenArgs {
  final int seed;
  final Difficulty difficulty;
  final Set<String> excludeWords;

  const _OfflineGenArgs(this.seed, this.difficulty, this.excludeWords);
}

/// Top-level entry point used by `compute` — must not capture any
/// closed-over state from the calling isolate.
Wordle7Puzzle _generateOfflineIsolate(_OfflineGenArgs args) {
  return PuzzleGenerator.generateRandom(
    args.seed,
    difficulty:   args.difficulty,
    excludeWords: args.excludeWords,
  );
}

/// Local-first puzzle store. The app owns level generation end-to-end
/// and never blocks the UI on the network:
///
///   1. Memory cache hit → return instantly.
///   2. SQLite cache hit → return instantly, spawn prefetch.
///   3. Cache miss → generate on a background isolate using the same
///      algorithm + seed + difficulty cycle + 5-level word-exclusion
///      lookback the server uses, persist locally, return.
///
/// After every successful serve we spin up a fire-and-forget prefetch
/// that tops up the next [_prefetchWindow] levels in SQLite. That way
/// "click next level" almost always hits the memcache or the SQLite
/// cache — no loading screen.
class LevelPuzzleStore {
  final UserGeneratedLevelRepository _cacheRepo;
  final int _userId;

  final Map<int, Wordle7Puzzle> _memCache = {};

  /// Levels currently being generated in the background. We gate on
  /// this so a prefetch and a hot-path request for the same level don't
  /// race into two concurrent isolate calls.
  final Map<int, Future<Wordle7Puzzle?>> _inflight = {};

  LevelPuzzleStore(this._cacheRepo, this._userId);

  // ── Parity constants ─────────────────────────────────────────────────────

  /// Difficulty cycle used for level generation.
  static const List<Difficulty> _defaultPattern = [
    Difficulty.medium,
    Difficulty.medium,
    Difficulty.hard,
    Difficulty.easy,
    Difficulty.medium,
  ];

  /// How many previous levels' words to exclude when generating a new
  /// puzzle, so the player doesn't see the same words back-to-back.
  static const int _lookbackLevels = 5;

  /// How many unplayed levels we keep generated ahead of the one the
  /// user is currently on.
  static const int _prefetchWindow = 5;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetch the puzzle for [level]. Resolves from the in-memory cache,
  /// then SQLite, then local generation. Never blocks on the network.
  Future<Wordle7Puzzle?> generate(int level) async {
    if (level < 1) return null;

    final hit = _memCache[level];
    if (hit != null) {
      _kickoffPrefetch(level);
      return hit;
    }

    final puzzle = await _resolveOrGenerate(level);
    if (puzzle != null) {
      _kickoffPrefetch(level);
    }
    return puzzle;
  }

  // ── Resolution pipeline ───────────────────────────────────────────────────

  /// Returns the cached puzzle for [level] if present, otherwise
  /// generates one, caches it, and returns it. Coalesces concurrent
  /// requests for the same level.
  Future<Wordle7Puzzle?> _resolveOrGenerate(int level) {
    final existing = _inflight[level];
    if (existing != null) return existing;

    final work = _doResolveOrGenerate(level).whenComplete(() {
      _inflight.remove(level);
    });
    _inflight[level] = work;
    return work;
  }

  Future<Wordle7Puzzle?> _doResolveOrGenerate(int level) async {
    final cached = await _readCached(level);
    if (cached != null) {
      _memCache[level] = cached;
      return cached;
    }
    return _generateLocal(level);
  }

  Future<Wordle7Puzzle?> _readCached(int level) async {
    try {
      final cached = await _cacheRepo.getByUserAndLevel(_userId, level);
      if (cached == null) return null;
      return Wordle7Puzzle.fromJson(
        jsonDecode(cached.puzzleJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generate [level] locally on a background isolate using a
  /// deterministic per-(user, level) seed, the difficulty cycle and the
  /// 5-level word-exclusion lookback.
  Future<Wordle7Puzzle?> _generateLocal(int level) async {
    try {
      final seed       = _seedFor(_userId, level);
      final difficulty = _defaultPattern[(level - 1) % _defaultPattern.length];
      final exclude    = await _collectRecentWords(level);

      // Isolate keeps the UI thread responsive — the backtracker can
      // take a few hundred ms on bigger grids.
      final puzzle = await compute(
        _generateOfflineIsolate,
        _OfflineGenArgs(seed, difficulty, exclude),
      );

      _memCache[level] = puzzle;
      try {
        await _cacheRepo.upsert(UserGeneratedLevelModel(
          userId:     _userId,
          level:      level,
          difficulty: difficulty.name,
          puzzleJson: jsonEncode(puzzle.toJson()),
        ));
      } catch (_) {}
      return puzzle;
    } catch (e) {
      debugPrint('LevelPuzzleStore: local generation failed for level $level: $e');
      return null;
    }
  }

  // ── Prefetch ──────────────────────────────────────────────────────────────

  /// Top up the next [_prefetchWindow] levels in the background so the
  /// user's next "next level" click hits a warm cache.
  void _kickoffPrefetch(int fromLevel) {
    unawaited(() async {
      for (int n = fromLevel + 1; n <= fromLevel + _prefetchWindow; n++) {
        if (_memCache.containsKey(n)) continue;
        if (_inflight.containsKey(n)) continue;
        final existing = await _readCached(n);
        if (existing != null) {
          _memCache[n] = existing;
          continue;
        }
        // Generate serially so prefetch can't saturate CPU while the
        // user is mid-game. The isolate call yields between levels.
        await _resolveOrGenerate(n);
      }
    }());
  }

  // ── Seed + exclusion helpers ──────────────────────────────────────────────

  /// Deterministic per-(user, level) seed.
  static int _seedFor(int userId, int level) {
    int hash = 17;
    hash = hash * 31 + userId;
    hash = hash * 31 + level;
    return hash & 0x7fffffff;
  }

  /// Gather words used in the previous [_lookbackLevels] levels so the
  /// generator can skip them.
  Future<Set<String>> _collectRecentWords(int level) async {
    if (level <= 1) return <String>{};
    final from = level - _lookbackLevels < 1 ? 1 : level - _lookbackLevels;
    final rows = await _cacheRepo.listRange(_userId, from, level - 1);
    final words = <String>{};
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.puzzleJson) as Map<String, dynamic>;
        final list = decoded['words'];
        if (list is List) {
          for (final entry in list) {
            if (entry is Map<String, dynamic>) {
              final w = entry['word'];
              if (w is String && w.isNotEmpty) words.add(w.toUpperCase());
            }
          }
        }
      } catch (_) {
        // Ignore malformed rows — they'll contribute nothing to the set.
      }
    }
    return words;
  }
}
