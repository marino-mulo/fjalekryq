import '../models/puzzle.dart';
import '../network/remote_level_repository.dart';

/// Fetches puzzles for numbered levels from the server.
/// Puzzles are cached in memory so replays don't re-fetch.
class LevelPuzzleStore {
  final RemoteLevelRepository _remoteRepo;
  final Map<int, Wordle7Puzzle> _cache = {};

  LevelPuzzleStore(this._remoteRepo);

  /// Fetch the puzzle for [level] from the server.
  /// Throws if the server call fails (offline, server down, etc.) —
  /// callers handle the error the same way as any other API failure.
  Future<Wordle7Puzzle?> generate(int level) async {
    if (_cache.containsKey(level)) {
      return _cache[level];
    }
    try {
      final remote = await _remoteRepo.getLevel(level);
      _cache[level] = remote.puzzle;
      return remote.puzzle;
    } catch (_) {
      return null;
    }
  }
}
