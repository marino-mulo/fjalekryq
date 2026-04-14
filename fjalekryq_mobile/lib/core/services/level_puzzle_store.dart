import '../database/repositories/level_repository.dart';
import '../models/puzzle.dart';
import '../models/level_config.dart';
import 'puzzle_generator.dart';

/// Generates puzzles on-demand from the seed stored in the DB.
/// Puzzles are cached in memory to avoid re-generating on replay.
class LevelPuzzleStore {
  final LevelRepository _levelRepo;
  final Map<int, Wordle7Puzzle> _cache = {};

  LevelPuzzleStore(this._levelRepo);

  /// Generate the puzzle for [level].
  /// Returns null if the level row doesn't exist.
  Future<Wordle7Puzzle?> generate(int level) async {
    // Return cached puzzle if available
    if (_cache.containsKey(level)) {
      return _cache[level];
    }

    final levelModel = await _levelRepo.getByLevel(level);
    if (levelModel == null) return null;

    final difficulty = difficultyForLevel(level);

    // Generate on main thread — dictionary is small (~880 words),
    // generation is fast. Isolate.run was too slow on emulators.
    // Use Future.delayed to let the loading UI paint first.
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final puzzle = PuzzleGenerator.generateRandom(
        levelModel.seed,
        difficulty: difficulty,
      );
      _cache[level] = puzzle;
      return puzzle;
    } catch (e) {
      // If generation fails, try with a different seed offset
      try {
        final puzzle = PuzzleGenerator.generateRandom(
          levelModel.seed + 7,
          difficulty: difficulty,
        );
        _cache[level] = puzzle;
        return puzzle;
      } catch (_) {
        return null;
      }
    }
  }
}
