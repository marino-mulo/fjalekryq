import 'dart:convert';

import '../database/models/user_generated_level_model.dart';
import '../database/repositories/user_generated_level_repository.dart';
import '../models/puzzle.dart';
import '../network/remote_level_repository.dart';

/// Fetches puzzles for numbered levels from the server, caches them to
/// the local `user_generated_levels` table, and falls back to that cache
/// when offline. The server stays authoritative — we only read from
/// cache if the network call fails.
class LevelPuzzleStore {
  final RemoteLevelRepository _remoteRepo;
  final UserGeneratedLevelRepository _cacheRepo;
  final int _userId;
  final Map<int, Wordle7Puzzle> _memCache = {};

  LevelPuzzleStore(this._remoteRepo, this._cacheRepo, this._userId);

  /// Fetch the puzzle for [level]. Tries the server first (so the user
  /// always gets the authoritative puzzle), then falls back to the
  /// per-user SQLite cache for offline replay.
  Future<Wordle7Puzzle?> generate(int level) async {
    if (_memCache.containsKey(level)) {
      return _memCache[level];
    }

    try {
      final remote = await _remoteRepo.getLevel(level);
      _memCache[level] = remote.puzzle;
      // Write-through to the local cache so this puzzle survives an
      // offline relaunch. Swallow cache errors — the game can still run.
      try {
        await _cacheRepo.upsert(UserGeneratedLevelModel(
          userId:     _userId,
          level:      remote.level,
          difficulty: remote.difficulty,
          puzzleJson: jsonEncode(remote.puzzle.toJson()),
        ));
      } catch (_) {}
      return remote.puzzle;
    } catch (_) {
      // Network failure — try the cache.
      try {
        final cached = await _cacheRepo.getByUserAndLevel(_userId, level);
        if (cached != null) {
          final puzzle = Wordle7Puzzle.fromJson(
            jsonDecode(cached.puzzleJson) as Map<String, dynamic>,
          );
          _memCache[level] = puzzle;
          return puzzle;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Evict the cached puzzle for a cleared level. Called after a win so
  /// the next playthrough re-fetches a fresh puzzle from the server.
  Future<void> evict(int level) async {
    _memCache.remove(level);
    try {
      await _cacheRepo.deleteByUserAndLevel(_userId, level);
    } catch (_) {}
  }
}
