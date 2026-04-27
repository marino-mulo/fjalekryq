import 'dart:math';
import '../models/puzzle.dart';
import '../models/level_config.dart';
import 'dictionary.dart';

/// Difficulty-based grid configuration.
class _DiffConfig {
  final List<int> sizes;
  final int minWords;
  final int minLetters;
  final int attempts;
  final int featuredLen;

  const _DiffConfig(this.sizes, this.minWords, this.minLetters, this.attempts, this.featuredLen);
}

// Kept in sync with FjalekryqApi/Puzzle/PuzzleGenerator.cs so offline
// generation produces the same tier feel as the server. Tuned so most
// placed words are 4–5 letters and Medium doesn't overshoot into what
// should be a Hard-tier grid.
const Map<Difficulty, _DiffConfig> _diffConfigs = {
  // MinLetters targets ≈ smallest_size² / 2 so density holds even when
  // the RNG picks the lower end of the size range.
  Difficulty.easy:   _DiffConfig([5, 6],   5, 14,  800, 5),
  Difficulty.medium: _DiffConfig([6, 7],   6, 20, 1000, 6),
  Difficulty.hard:   _DiffConfig([8, 9],   7, 28, 1200, 7),
  Difficulty.expert: _DiffConfig([9, 10],  8, 40, 1500, 8),
};

/// Generates Wordle7 (crossword) puzzles using backtracking word placement.
/// Ported from Wordle7Generator.cs
class PuzzleGenerator {
  PuzzleGenerator._();

  /// Generate a random puzzle for the given difficulty tier.
  static Wordle7Puzzle generateRandom(int seed, {
    Set<String>? excludeWords,
    Difficulty difficulty = Difficulty.medium,
  }) {
    final rng = Random(seed);
    final cfg = _diffConfigs[difficulty] ?? _diffConfigs[Difficulty.medium]!;

    // Pick a random grid size for this difficulty
    var usedSize = cfg.sizes[rng.nextInt(cfg.sizes.length)];

    var result = _generatePuzzle(
      rng, usedSize, cfg.minWords, cfg.minLetters, cfg.attempts,
      difficulty, cfg.featuredLen, excludeWords,
    );

    // Retry with relaxed requirements, same size
    if (result == null) {
      result = _generatePuzzle(
        rng, usedSize,
        max(3, cfg.minWords - 3),
        max(8, cfg.minLetters - 10),
        cfg.attempts * 2,
        difficulty, cfg.featuredLen, excludeWords,
      );
    }

    // Try each size in the difficulty range with very relaxed requirements
    if (result == null) {
      for (final fallbackSize in cfg.sizes) {
        result = _generatePuzzle(
          rng, fallbackSize, 3, 8, 2000,
          difficulty, min(fallbackSize, cfg.featuredLen), null,
        );
        if (result != null) {
          usedSize = fallbackSize;
          break;
        }
      }
    }

    // Absolute last resort: easy difficulty pool, smallest grid, minimal words
    if (result == null) {
      usedSize = 5;
      result = _generatePuzzle(
        rng, 5, 3, 8, 2000,
        Difficulty.easy, 5, null,
      );
    }

    if (result == null) {
      throw StateError("Failed to generate puzzle for difficulty '$difficulty'");
    }

    // Strip any all-empty edge rows/columns so the rendered board has no
    // dead margin around the puzzle. The placement loop centres the
    // featured word but smaller crossing words can leave the bottom or
    // right edge unused — without this, an 8×8 puzzle keeps showing as a
    // 9×9 grid with a blank ring.
    final trimmed = _trimToContent(result.grid, result.words);
    return Wordle7Puzzle(
      gridSize: trimmed.size,
      solution: trimmed.grid,
      words:    trimmed.words,
      swapLimit: result.swapLimit,
      hash: _computeHash(trimmed.grid),
    );
  }

  /// Crop empty rows/columns from each edge of [grid] and shift every
  /// [WordEntry]'s coordinates by the same amount. The result is padded
  /// back to a square (the renderer assumes square boards) using the
  /// larger of the trimmed height / width.
  static _TrimmedPuzzle _trimToContent(
    List<List<String>> grid,
    List<WordEntry> words,
  ) {
    final size = grid.length;
    int minR = size, minC = size, maxR = -1, maxC = -1;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] != 'X') {
          if (r < minR) minR = r;
          if (c < minC) minC = c;
          if (r > maxR) maxR = r;
          if (c > maxC) maxC = c;
        }
      }
    }
    if (maxR < 0) {
      // Empty grid — shouldn't happen, but stay safe.
      return _TrimmedPuzzle(grid, words, size);
    }

    final h = maxR - minR + 1;
    final w = maxC - minC + 1;
    final newSize = max(h, w);

    // Centre the cropped rectangle in the new square so any padding is
    // split evenly across both sides instead of dumped on one edge.
    final offR = (newSize - h) ~/ 2;
    final offC = (newSize - w) ~/ 2;

    final newGrid = List.generate(newSize, (_) => List.filled(newSize, 'X'));
    for (int r = 0; r < h; r++) {
      for (int c = 0; c < w; c++) {
        newGrid[r + offR][c + offC] = grid[minR + r][minC + c];
      }
    }

    final newWords = words
        .map((w) => WordEntry(
              word: w.word,
              row: w.row - minR + offR,
              col: w.col - minC + offC,
              direction: w.direction,
            ))
        .toList();

    return _TrimmedPuzzle(newGrid, newWords, newSize);
  }

  static String _computeHash(List<List<String>> solution) {
    final flat = solution.map((r) => r.join(',')).join('|');
    return flat.hashCode.toRadixString(16).padLeft(8, '0');
  }

  static _PuzzleResult? _generatePuzzle(
    Random rng,
    int size,
    int minWords,
    int minLetters,
    int maxAttempts,
    Difficulty difficulty,
    int featuredLen,
    Set<String>? excludeWords,
  ) {
    var pool = Wordle7Dictionary.getPool(difficulty);
    var bigWords = Wordle7Dictionary.getWordsByLength(featuredLen);

    // Filter out excluded words
    if (excludeWords != null && excludeWords.isNotEmpty) {
      pool = pool.where((w) => !excludeWords.contains(w)).toList();
      bigWords = bigWords.where((w) => !excludeWords.contains(w)).toList();
    }

    List<List<String>>? bestGrid;
    List<WordEntry>? bestWords;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      _shuffle(pool, rng);
      var grid = _makeGrid(size);
      final wordSet = <String>{};
      final placed = <_PlacedWord>[];

      // Place featured big word first (in center, horizontally)
      String first;
      if (bigWords.isNotEmpty) {
        _shuffle(bigWords, rng);
        first = bigWords[0];
      } else {
        first = pool[0];
      }
      if (first.length > size) continue;

      final r = size ~/ 2;
      final c = max(0, (size - first.length) ~/ 2);
      final newGrid = _tryPlace(grid, first, r, c, 'horizontal', size);
      if (newGrid == null) continue;
      grid = newGrid;
      wordSet.add(first);
      placed.add(_PlacedWord(first, r, c, 'horizontal'));

      // Try to add remaining words — multiple passes.
      // Keep only short words (≤ 5 letters) for the fill so the puzzle
      // reads as "one big featured word + lots of 4–5 letter crossings".
      // Without this filter the pool's 6/7/8-letter words land too
      // often and a Hard board ends up with 4 long words instead of
      // the intended single feature.
      var remaining = pool
          .where((w) => !wordSet.contains(w) && w.length <= 5)
          .toList();

      for (int pass = 0; pass < 3; pass++) {
        _shuffle(remaining, rng);
        final stillRemaining = <String>[];
        for (final word in remaining) {
          if (wordSet.contains(word)) continue;
          if (word.length > size) {
            stillRemaining.add(word);
            continue;
          }

          final placements = _findAllPlacements(grid, word, wordSet, size);
          if (placements.isNotEmpty) {
            final pick = placements[rng.nextInt(placements.length)];
            grid = pick.grid;
            wordSet.add(word);
            placed.add(_PlacedWord(word, pick.row, pick.col, pick.dir));
          } else {
            stillRemaining.add(word);
          }
        }
        remaining = stillRemaining;
      }

      final nWords = placed.length;
      final nLetters = _countLetters(grid);

      if (nWords >= minWords &&
          nLetters >= minLetters &&
          !_hasIsolatedLetters(grid, size) &&
          _checkConnectivity(grid, size)) {
        // Clean placed words
        final cleanPlaced = _cleanPlacedWords(grid, placed, size);
        final finalWords = cleanPlaced
            .map((p) => WordEntry(
                  word: p.word,
                  row: p.row,
                  col: p.col,
                  direction: p.dir == 'horizontal'
                      ? WordDirection.horizontal
                      : WordDirection.vertical,
                ))
            .toList();

        // First-valid-wins: matches PuzzleGenerator.cs. Saves a lot of
        // CPU vs. best-of-N on mobile and keeps client + server output
        // behaviourally equivalent.
        bestGrid = grid;
        bestWords = finalWords;
        break;
      }
    }

    if (bestGrid != null && bestWords != null) {
      // Compute swap limit
      final filledCells = bestGrid.fold<int>(
        0, (sum, row) => sum + row.where((c) => c != 'X').length,
      );
      final swapLimit = _computeSwapLimit(filledCells, difficulty);

      return _PuzzleResult(bestGrid, bestWords, swapLimit);
    }
    return null;
  }

  static int _computeSwapLimit(int filledCells, Difficulty difficulty) {
    // 0.50 keeps puzzles tight-but-solvable. Kept in sync with
    // FjalekryqApi/Puzzle/PuzzleGenerator.cs.
    final base = (filledCells * 0.50).ceil();
    switch (difficulty) {
      case Difficulty.easy:   return base + 3;
      case Difficulty.medium: return base + 5;
      case Difficulty.hard:   return base + 8;
      case Difficulty.expert: return base + 10;
    }
  }

  static List<List<String>> _makeGrid(int size) {
    return List.generate(size, (_) => List.filled(size, 'X'));
  }

  static List<List<String>>? _tryPlace(
    List<List<String>> grid, String word, int row, int col, String direction, int size,
  ) {
    final g = grid.map((r) => List<String>.from(r)).toList();
    for (int i = 0; i < word.length; i++) {
      final r = row + (direction == 'vertical' ? i : 0);
      final c = col + (direction == 'horizontal' ? i : 0);
      if (r >= size || c >= size) return null;
      final ch = word[i];
      if (g[r][c] != 'X' && g[r][c] != ch) return null;
      g[r][c] = ch;
    }
    return g;
  }

  static bool _wordSharesCell(
    List<List<String>> grid, String word, int row, int col, String direction, int size,
  ) {
    for (int i = 0; i < word.length; i++) {
      final r = row + (direction == 'vertical' ? i : 0);
      final c = col + (direction == 'horizontal' ? i : 0);
      if (r < size && c < size && grid[r][c] != 'X') return true;
    }
    return false;
  }

  static List<String> _findAllRuns(List<List<String>> grid, int size) {
    final runs = <String>[];

    // Horizontal runs
    for (int r = 0; r < size; r++) {
      int c = 0;
      while (c < size) {
        if (grid[r][c] != 'X') {
          final buf = StringBuffer();
          while (c < size && grid[r][c] != 'X') {
            buf.write(grid[r][c]);
            c++;
          }
          if (buf.length >= 2) runs.add(buf.toString());
        } else {
          c++;
        }
      }
    }

    // Vertical runs
    for (int c = 0; c < size; c++) {
      int r = 0;
      while (r < size) {
        if (grid[r][c] != 'X') {
          final buf = StringBuffer();
          while (r < size && grid[r][c] != 'X') {
            buf.write(grid[r][c]);
            r++;
          }
          if (buf.length >= 2) runs.add(buf.toString());
        } else {
          r++;
        }
      }
    }

    return runs;
  }

  static bool _isValidAfterPlacement(
    List<List<String>> grid, Set<String> wordSet, int size,
  ) {
    for (final run in _findAllRuns(grid, size)) {
      if (!wordSet.contains(run)) return false;
    }
    return true;
  }

  static List<_Placement> _findAllPlacements(
    List<List<String>> grid, String word, Set<String> wordSet, int size,
  ) {
    final placements = <_Placement>[];
    final newWs = <String>{...wordSet, word};

    for (final direction in ['horizontal', 'vertical']) {
      final maxR = size - (direction == 'vertical' ? word.length : 1);
      final maxC = size - (direction == 'horizontal' ? word.length : 1);

      for (int r = 0; r <= maxR; r++) {
        for (int c = 0; c <= maxC; c++) {
          final newGrid = _tryPlace(grid, word, r, c, direction, size);
          if (newGrid == null) continue;

          // Must share at least one cell with existing letters
          if (_countLetters(grid) > 0 &&
              !_wordSharesCell(grid, word, r, c, direction, size)) {
            continue;
          }

          if (_isValidAfterPlacement(newGrid, newWs, size)) {
            placements.add(_Placement(r, c, direction, newGrid));
          }
        }
      }
    }
    return placements;
  }

  static int _countLetters(List<List<String>> grid) {
    int count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell != 'X') count++;
      }
    }
    return count;
  }

  static bool _hasIsolatedLetters(List<List<String>> grid, int size) {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == 'X') continue;

        // Horizontal run length
        int hStart = c;
        while (hStart > 0 && grid[r][hStart - 1] != 'X') {
          hStart--;
        }
        int hEnd = c;
        while (hEnd < size - 1 && grid[r][hEnd + 1] != 'X') {
          hEnd++;
        }
        final hLen = hEnd - hStart + 1;

        // Vertical run length
        int vStart = r;
        while (vStart > 0 && grid[vStart - 1][c] != 'X') {
          vStart--;
        }
        int vEnd = r;
        while (vEnd < size - 1 && grid[vEnd + 1][c] != 'X') {
          vEnd++;
        }
        final vLen = vEnd - vStart + 1;

        if (hLen < 2 && vLen < 2) return true;
      }
    }
    return false;
  }

  static bool _checkConnectivity(List<List<String>> grid, int size) {
    int startR = -1, startC = -1;
    for (int r = 0; r < size && startR < 0; r++) {
      for (int c = 0; c < size && startR < 0; c++) {
        if (grid[r][c] != 'X') {
          startR = r;
          startC = c;
        }
      }
    }
    if (startR < 0) return true;

    final visited = <String>{};
    final queue = <List<int>>[];
    visited.add('$startR,$startC');
    queue.add([startR, startC]);

    const dr = [-1, 1, 0, 0];
    const dc = [0, 0, -1, 1];

    while (queue.isNotEmpty) {
      final pos = queue.removeAt(0);
      final cr = pos[0], cc = pos[1];
      for (int d = 0; d < 4; d++) {
        final nr = cr + dr[d];
        final nc = cc + dc[d];
        final key = '$nr,$nc';
        if (nr >= 0 && nr < size && nc >= 0 && nc < size &&
            grid[nr][nc] != 'X' && !visited.contains(key)) {
          visited.add(key);
          queue.add([nr, nc]);
        }
      }
    }

    int totalFilled = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] != 'X') totalFilled++;
      }
    }
    return visited.length == totalFilled;
  }

  static List<_PlacedWord> _cleanPlacedWords(
    List<List<String>> grid, List<_PlacedWord> placed, int size,
  ) {
    final actualRuns = <String>{};

    // Horizontal runs
    for (int r = 0; r < size; r++) {
      int c = 0;
      while (c < size) {
        if (grid[r][c] != 'X') {
          final start = c;
          final buf = StringBuffer();
          while (c < size && grid[r][c] != 'X') {
            buf.write(grid[r][c]);
            c++;
          }
          if (buf.length >= 2) actualRuns.add('${buf.toString()},$r,$start,horizontal');
        } else {
          c++;
        }
      }
    }

    // Vertical runs
    for (int c = 0; c < size; c++) {
      int r = 0;
      while (r < size) {
        if (grid[r][c] != 'X') {
          final start = r;
          final buf = StringBuffer();
          while (r < size && grid[r][c] != 'X') {
            buf.write(grid[r][c]);
            r++;
          }
          if (buf.length >= 2) actualRuns.add('${buf.toString()},$start,$c,vertical');
        } else {
          r++;
        }
      }
    }

    final clean = <_PlacedWord>[];
    final usedRuns = <String>{};
    for (final p in placed) {
      final key = '${p.word},${p.row},${p.col},${p.dir}';
      if (actualRuns.contains(key) && !usedRuns.contains(key)) {
        clean.add(p);
        usedRuns.add(key);
      }
    }
    return clean;
  }

  static void _shuffle<T>(List<T> list, Random rng) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}

class _PlacedWord {
  final String word;
  final int row;
  final int col;
  final String dir;
  const _PlacedWord(this.word, this.row, this.col, this.dir);
}

class _Placement {
  final int row;
  final int col;
  final String dir;
  final List<List<String>> grid;
  const _Placement(this.row, this.col, this.dir, this.grid);
}

class _PuzzleResult {
  final List<List<String>> grid;
  final List<WordEntry> words;
  final int swapLimit;
  const _PuzzleResult(this.grid, this.words, this.swapLimit);
}

class _TrimmedPuzzle {
  final List<List<String>> grid;
  final List<WordEntry> words;
  final int size;
  const _TrimmedPuzzle(this.grid, this.words, this.size);
}
