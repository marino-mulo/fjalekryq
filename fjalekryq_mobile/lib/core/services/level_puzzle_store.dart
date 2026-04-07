import '../models/puzzle.dart';
import '../models/level_config.dart';
import 'puzzle_generator.dart';

/// Pre-generates one puzzle per level so they're available instantly.
/// Ported from LevelPuzzleStore.cs
class LevelPuzzleStore {
  final Map<int, Wordle7Puzzle> _store = {};

  /// Whether puzzles have been generated.
  bool get isReady => _store.isNotEmpty;

  /// Generate all 10 level puzzles.
  void generateAll() {
    for (int level = 1; level <= totalActiveLevels; level++) {
      try {
        _store[level] = _build(level);
      } catch (e) {
        // Log but don't crash — individual level failure shouldn't block others
        print('[LevelPuzzleStore] Failed to generate level $level: $e');
      }
    }
  }

  /// Get the puzzle for a specific level.
  Wordle7Puzzle? get(int level) => _store[level];

  /// Regenerate a specific level.
  void regenerate(int level) {
    _store[level] = _build(level);
  }

  static Wordle7Puzzle _build(int level) {
    // Fixed seed per level so the puzzle is stable
    final seed = level * 99991 + 42013;
    final difficulty = difficultyForLevel(level);
    return PuzzleGenerator.generateRandom(seed, difficulty: difficulty);
  }
}
