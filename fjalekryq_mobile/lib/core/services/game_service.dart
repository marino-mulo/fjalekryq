import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/puzzle.dart';
import '../database/repositories/game_state_repository.dart';
import '../database/repositories/progress_repository.dart';
import '../database/models/game_state_model.dart';

/// Cell color in Wordle style.
enum CellColor { green, yellow, grey }

/// Saved game state for persistence.
class SavedGameState {
  final Wordle7Puzzle puzzle;
  final List<List<String>> grid;
  final int swapCount;
  final int hintCount;
  final int totalSwapCount;
  final int level;

  const SavedGameState({
    required this.puzzle,
    required this.grid,
    required this.swapCount,
    required this.hintCount,
    required this.totalSwapCount,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
        'puzzle': puzzle.toJson(),
        'grid': grid.map((r) => r.toList()).toList(),
        'swapCount': swapCount,
        'hintCount': hintCount,
        'totalSwapCount': totalSwapCount,
        'level': level,
      };

  factory SavedGameState.fromJson(Map<String, dynamic> json) => SavedGameState(
        puzzle: Wordle7Puzzle.fromJson(json['puzzle'] as Map<String, dynamic>),
        grid: (json['grid'] as List)
            .map((r) => (r as List).map((c) => c as String).toList())
            .toList(),
        swapCount: json['swapCount'] as int,
        hintCount: json['hintCount'] as int,
        totalSwapCount: (json['totalSwapCount'] as int?) ?? json['swapCount'] as int,
        level: json['level'] as int,
      );
}

/// Animation data for a cell swap.
class SwapAnimation {
  final int row, col, fromRow, fromCol;
  const SwapAnimation(this.row, this.col, this.fromRow, this.fromCol);
}

/// Core game logic service managing grid state, swaps, hints, solve.
/// Persistence now uses SQLite via GameStateRepository + ProgressRepository.
/// SharedPreferences still used for cooldown timers only.
class GameService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final GameStateRepository _gameStateRepo;
  final ProgressRepository _progressRepo;
  final int _userId;

  // Puzzle data
  List<List<String>> _solutionGrid = [];
  List<WordEntry> _wordList = [];
  int _gridSize = 7;
  Wordle7Puzzle? _currentPuzzle;
  bool _tutorialMode = false;

  // Grid state
  List<List<String>> _grid = [];
  ({int row, int col})? _selectedCell;
  bool _gameWon = false;
  bool _gameLost = false;
  int _swapCount = 0;
  int _totalSwapCount = 0;
  int _swapLimit = 0;
  int _hintCount = 0;
  bool _solveWordUsed = false;

  // Animation state
  List<SwapAnimation>? _lastSwap;
  List<({int row, int col})> _hintSwappedCells = [];

  // Hint cooldown
  bool _hintCooldown = false;
  int _hintCooldownRemaining = 0;

  // Solve cooldown
  bool _solveWordCooldown = false;
  int _solveWordCooldownRemaining = 0;

  // Hint message
  String _hintMessage = '';

  // Pre-computed: which words pass through each cell
  final Map<String, List<int>> _cellToWords = {};

  // Current playing level (for save/restore)
  int _currentLevel = 1;

  GameService(this._prefs, this._gameStateRepo, this._progressRepo, this._userId);

  // ── Getters ──────────────────────────────────────────────
  List<List<String>> get grid => _grid;
  ({int row, int col})? get selectedCell => _selectedCell;
  bool get gameWon => _gameWon;
  bool get gameLost => _gameLost;
  int get swapCount => _swapCount;
  int get totalSwapCount => _totalSwapCount;
  int get swapLimit => _swapLimit;
  int get swapsRemaining => max(0, _swapLimit - _swapCount);
  int get hintCount => _hintCount;
  bool get solveWordUsed => _solveWordUsed;
  List<SwapAnimation>? get lastSwap => _lastSwap;
  List<({int row, int col})> get hintSwappedCells => _hintSwappedCells;
  bool get hintCooldown => _hintCooldown;
  int get hintCooldownRemaining => _hintCooldownRemaining;
  bool get solveWordCooldown => _solveWordCooldown;
  int get solveWordCooldownRemaining => _solveWordCooldownRemaining;
  String get hintMessage => _hintMessage;
  int get gridSize => _gridSize;
  List<WordEntry> get words => _wordList;
  List<List<String>> get solution => _solutionGrid;
  bool get canHint => !_gameWon && !_gameLost && !_hintCooldown;
  bool get canSolveWord => !_gameWon && !_gameLost && !_solveWordCooldown;

  void setTutorialMode(bool enabled) => _tutorialMode = enabled;

  // ── Cell colors ──────────────────────────────────────────

  /// Compute Wordle-style color for each cell.
  Map<String, CellColor> get cellColors {
    final colors = <String, CellColor>{};
    if (_grid.isEmpty || _solutionGrid.isEmpty) return colors;

    // Step 1: Mark greens
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] == 'X') continue;
        if (_grid[r][c] == _solutionGrid[r][c]) {
          colors['$r,$c'] = CellColor.green;
        }
      }
    }

    // Step 2: For each word, determine yellows with frequency counting
    final yellowCells = <String>{};

    for (int wi = 0; wi < _wordList.length; wi++) {
      final w = _wordList[wi];
      final positions = <(int, int)>[];
      for (int j = 0; j < w.word.length; j++) {
        final r = w.direction == WordDirection.horizontal ? w.row : w.row + j;
        final c = w.direction == WordDirection.horizontal ? w.col + j : w.col;
        positions.add((r, c));
      }

      final solutionLetters = positions.map((p) => _solutionGrid[p.$1][p.$2]).toList();
      final currentLetters = positions.map((p) => _grid[p.$1][p.$2]).toList();

      // Count remaining solution letter frequencies (excluding green matches)
      final remaining = <String, int>{};
      for (int j = 0; j < positions.length; j++) {
        if (currentLetters[j] == solutionLetters[j]) continue;
        final sl = solutionLetters[j];
        remaining[sl] = (remaining[sl] ?? 0) + 1;
      }

      // Distribute yellows to non-green positions
      for (int j = 0; j < positions.length; j++) {
        if (currentLetters[j] == solutionLetters[j]) continue;
        final key = '${positions[j].$1},${positions[j].$2}';
        final letter = currentLetters[j];
        if ((remaining[letter] ?? 0) > 0) {
          yellowCells.add(key);
          remaining[letter] = remaining[letter]! - 1;
        }
      }
    }

    // Step 3: Assign yellow or grey to non-green cells
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] == 'X') continue;
        final key = '$r,$c';
        if (colors.containsKey(key)) continue;
        colors[key] = yellowCells.contains(key) ? CellColor.yellow : CellColor.grey;
      }
    }

    return colors;
  }

  // ── Initialize ───────────────────────────────────────────

  void initPuzzle(Wordle7Puzzle puzzle, {int level = 1}) {
    _currentPuzzle = puzzle;
    _currentLevel = level;
    _gridSize = puzzle.gridSize;
    _solutionGrid = puzzle.solution.map((r) => List<String>.from(r)).toList();
    _wordList = puzzle.words;
    _swapLimit = puzzle.swapLimit;
    _gameWon = false;
    _gameLost = false;
    _selectedCell = null;
    _swapCount = 0;
    _totalSwapCount = 0;
    _solveWordUsed = false;
    _hintCount = 0;
    _clearHintState();
    _solveWordCooldown = false;
    _solveWordCooldownRemaining = 0;
    _buildCellToWords();
    _grid = _scrambleGrid(_solutionGrid);
    _saveState();
    notifyListeners();
  }

  /// Restore a saved game state without re-scrambling.
  void restorePuzzle(
    Wordle7Puzzle puzzle,
    List<List<String>> grid,
    int swapCount,
    int hintCount, [
    int? totalSwapCount,
    int level = 1,
  ]) {
    _currentPuzzle = puzzle;
    _currentLevel = level;
    _gridSize = puzzle.gridSize;
    _solutionGrid = puzzle.solution.map((r) => List<String>.from(r)).toList();
    _wordList = puzzle.words;
    _swapLimit = puzzle.swapLimit;
    _gameWon = false;
    _gameLost = false;
    _selectedCell = null;
    _swapCount = swapCount;
    _totalSwapCount = totalSwapCount ?? swapCount;
    _hintCount = hintCount;
    _clearHintState();
    _buildCellToWords();
    _grid = grid;
    _restoreCooldowns();
    notifyListeners();
  }

  // ── Cell selection & swap ────────────────────────────────

  bool isCellLocked(int row, int col) {
    return cellColors['$row,$col'] == CellColor.green;
  }

  void selectCell(int row, int col) {
    if (_gameWon || _gameLost) return;
    if (_grid[row][col] == 'X') return;
    if (isCellLocked(row, col)) return;

    if (_selectedCell == null) {
      _selectedCell = (row: row, col: col);
      notifyListeners();
      return;
    }

    if (_selectedCell!.row == row && _selectedCell!.col == col) {
      _selectedCell = null;
      notifyListeners();
      return;
    }

    _swapCells(_selectedCell!.row, _selectedCell!.col, row, col);
    _selectedCell = null;
    notifyListeners();
  }

  void _swapCells(int r1, int c1, int r2, int c2) {
    final g = _grid.map((r) => List<String>.from(r)).toList();
    final temp = g[r1][c1];
    g[r1][c1] = g[r2][c2];
    g[r2][c2] = temp;
    _grid = g;
    _lastSwap = [
      SwapAnimation(r1, c1, r2, c2),
      SwapAnimation(r2, c2, r1, c1),
    ];
    _swapCount++;
    _totalSwapCount++;

    _checkWin();
    if (!_gameWon) _checkLoss();
    _saveState();
  }

  void _checkWin() {
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] != _solutionGrid[r][c]) return;
      }
    }
    _gameWon = true;
    _clearSavedState();
  }

  void _checkLoss() {
    if (_swapCount >= _swapLimit) {
      _gameLost = true;
      _selectedCell = null;
      _clearSavedState();
    }
  }

  // ── Continue after loss (+5 extra swaps) ─────────────────

  void continueGame() {
    if (!_gameLost) return;
    _gameLost = false;
    _swapLimit += 5;
    _selectedCell = null;
    _saveState();
    notifyListeners();
  }

  /// Add extra swaps mid-game (e.g. when 5 moves remain, buy +5).
  void addExtraMoves(int count) {
    _swapLimit += count;
    _saveState();
    notifyListeners();
  }

  // ── Reset ────────────────────────────────────────────────

  void resetPuzzle() {
    _gameWon = false;
    _gameLost = false;
    _selectedCell = null;
    _swapCount = 0;
    _totalSwapCount = 0;
    _solveWordUsed = false;
    _clearHintState();
    _solveWordCooldown = false;
    _solveWordCooldownRemaining = 0;
    _clearSavedState();
    _grid = _scrambleGrid(_solutionGrid);
    notifyListeners();
  }

  // ── Hint ─────────────────────────────────────────────────

  void hint() {
    if (!canHint) return;
    _hintCount++;

    // Find all wrong cells
    final wrongCells = <({int row, int col})>[];
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] != 'X' && _grid[r][c] != _solutionGrid[r][c]) {
          wrongCells.add((row: r, col: c));
        }
      }
    }
    if (wrongCells.isEmpty) return;

    // Pick a random wrong cell
    final rng = Random();
    final target = wrongCells[rng.nextInt(wrongCells.length)];
    final correctLetter = _solutionGrid[target.row][target.col];

    // Find where the correct letter currently sits
    ({int row, int col})? sourceCell;
    for (final cell in wrongCells) {
      if (cell.row == target.row && cell.col == target.col) continue;
      if (_grid[cell.row][cell.col] == correctLetter) {
        sourceCell = cell;
        break;
      }
    }

    if (sourceCell == null) {
      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (r == target.row && c == target.col) continue;
          if (_grid[r][c] == correctLetter && _grid[r][c] != _solutionGrid[r][c]) {
            sourceCell = (row: r, col: c);
            break;
          }
        }
        if (sourceCell != null) break;
      }
    }

    if (sourceCell == null) return;

    // Perform the swap (does NOT count toward move limit)
    final newGrid = _grid.map((r) => List<String>.from(r)).toList();
    final temp = newGrid[target.row][target.col];
    newGrid[target.row][target.col] = newGrid[sourceCell.row][sourceCell.col];
    newGrid[sourceCell.row][sourceCell.col] = temp;
    _grid = newGrid;
    _lastSwap = [
      SwapAnimation(target.row, target.col, sourceCell.row, sourceCell.col),
      SwapAnimation(sourceCell.row, sourceCell.col, target.row, target.col),
    ];
    _totalSwapCount++;
    _selectedCell = null;

    // Highlight the two swapped cells
    _hintSwappedCells = [target, sourceCell];

    _hintMessage = 'Një shkronjë u vendos në vendin e duhur!';
    _checkWin();
    _saveState();

    // 3-second cooldown
    _startHintCooldown();
    notifyListeners();

    // Clear hint highlights after 2s
    Future.delayed(const Duration(seconds: 2), () {
      _hintSwappedCells = [];
      notifyListeners();
    });

    // Clear hint message after 5s
    Future.delayed(const Duration(seconds: 5), () {
      _hintMessage = '';
      notifyListeners();
    });
  }

  void _startHintCooldown() {
    _hintCooldown = true;
    _hintCooldownRemaining = 3;
    _prefs.setInt('wordle7_hint_cooldown_end', DateTime.now().millisecondsSinceEpoch + 3000);

    _tickCooldown(
      getRemainingFn: () => _hintCooldownRemaining,
      setRemainingFn: (v) => _hintCooldownRemaining = v,
      setCooldownFn: (v) => _hintCooldown = v,
      prefKey: 'wordle7_hint_cooldown_end',
    );
  }

  // ── Solve Word ───────────────────────────────────────────

  void solveWord() {
    if (!canSolveWord) return;
    _solveWordUsed = true;

    // Sort words by length descending and pick the 2nd unsolved one
    final sorted = List<WordEntry>.from(_wordList)
      ..sort((a, b) => b.word.length.compareTo(a.word.length));

    WordEntry? target;
    for (int i = 0; i < sorted.length; i++) {
      if (i < 1) continue; // skip top 1
      final w = sorted[i];
      bool hasMismatch = false;
      for (int j = 0; j < w.word.length; j++) {
        final r = w.direction == WordDirection.horizontal ? w.row : w.row + j;
        final c = w.direction == WordDirection.horizontal ? w.col + j : w.col;
        if (_grid[r][c] != _solutionGrid[r][c]) {
          hasMismatch = true;
          break;
        }
      }
      if (hasMismatch) {
        target = w;
        break;
      }
    }
    target ??= sorted[min(1, sorted.length - 1)];

    // Get positions of the target word
    final positions = <({int row, int col})>[];
    for (int j = 0; j < target.word.length; j++) {
      final r = target.direction == WordDirection.horizontal ? target.row : target.row + j;
      final c = target.direction == WordDirection.horizontal ? target.col + j : target.col;
      positions.add((row: r, col: c));
    }

    // Place the correct letters
    final newGrid = _grid.map((r) => List<String>.from(r)).toList();
    final swapAnim = <SwapAnimation>[];

    for (int j = 0; j < positions.length; j++) {
      final pos = positions[j];
      final correctLetter = _solutionGrid[pos.row][pos.col];
      if (newGrid[pos.row][pos.col] == correctLetter) continue;

      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (r == pos.row && c == pos.col) continue;
          if (newGrid[r][c] == correctLetter && newGrid[r][c] != _solutionGrid[r][c]) {
            newGrid[r][c] = newGrid[pos.row][pos.col];
            newGrid[pos.row][pos.col] = correctLetter;
            swapAnim.add(SwapAnimation(pos.row, pos.col, r, c));
            swapAnim.add(SwapAnimation(r, c, pos.row, pos.col));
            break;
          }
        }
        if (newGrid[pos.row][pos.col] == correctLetter) break;
      }
    }

    _grid = newGrid;
    _lastSwap = swapAnim.isNotEmpty
        ? swapAnim
        : positions.map((p) => SwapAnimation(p.row, p.col, p.row, p.col)).toList();
    _totalSwapCount += target.word.length;
    _selectedCell = null;

    _hintSwappedCells = positions;
    _hintMessage = 'Fjala "${target.word}" u zgjidh!';
    _checkWin();
    if (!_gameWon) _checkLoss();
    _saveState();

    // 3-second cooldown
    _startSolveCooldown();
    notifyListeners();

    // Clear highlights after 2.5s
    Future.delayed(const Duration(milliseconds: 2500), () {
      _hintSwappedCells = [];
      notifyListeners();
    });

    // Clear hint message after 5s
    Future.delayed(const Duration(seconds: 5), () {
      _hintMessage = '';
      notifyListeners();
    });
  }

  void _startSolveCooldown() {
    _solveWordCooldown = true;
    _solveWordCooldownRemaining = 3;
    _prefs.setInt('wordle7_solve_cooldown_end', DateTime.now().millisecondsSinceEpoch + 3000);

    _tickCooldown(
      getRemainingFn: () => _solveWordCooldownRemaining,
      setRemainingFn: (v) => _solveWordCooldownRemaining = v,
      setCooldownFn: (v) => _solveWordCooldown = v,
      prefKey: 'wordle7_solve_cooldown_end',
    );
  }

  /// Generic 1-second ticker for cooldowns.
  void _tickCooldown({
    required int Function() getRemainingFn,
    required void Function(int) setRemainingFn,
    required void Function(bool) setCooldownFn,
    required String prefKey,
  }) {
    Future.delayed(const Duration(seconds: 1), () {
      final r = getRemainingFn() - 1;
      setRemainingFn(r);
      if (r <= 0) {
        setCooldownFn(false);
        setRemainingFn(0);
        _prefs.remove(prefKey);
      } else {
        _tickCooldown(
          getRemainingFn: getRemainingFn,
          setRemainingFn: setRemainingFn,
          setCooldownFn: setCooldownFn,
          prefKey: prefKey,
        );
      }
      notifyListeners();
    });
  }

  // ── Scramble ─────────────────────────────────────────────

  List<List<String>> _scrambleGrid(List<List<String>> solution) {
    final rng = Random();
    final letters = <String>[];
    final positions = <(int, int)>[];

    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (solution[r][c] != 'X') {
          letters.add(solution[r][c]);
          positions.add((r, c));
        }
      }
    }

    final total = letters.length;
    final targetGreen = max(1, (total * (0.15 + rng.nextDouble() * 0.05)).round());

    // Choose which indices to pre-solve
    final allIndices = List.generate(total, (i) => i);
    for (int i = allIndices.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = allIndices[i];
      allIndices[i] = allIndices[j];
      allIndices[j] = tmp;
    }
    final preSolvedSet = allIndices.take(targetGreen).toSet();

    // Collect free indices and shuffle their letters
    final freeIndices = allIndices.skip(targetGreen).toList();
    final freeLetters = freeIndices.map((i) => letters[i]).toList();

    for (int i = freeLetters.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = freeLetters[i];
      freeLetters[i] = freeLetters[j];
      freeLetters[j] = tmp;
    }

    // Build result grid
    final grid = solution.map((r) => List<String>.from(r)).toList();
    int fi = 0;
    for (int i = 0; i < total; i++) {
      final (r, c) = positions[i];
      grid[r][c] = preSolvedSet.contains(i) ? letters[i] : freeLetters[fi++];
    }
    return grid;
  }

  // ── Persistence (SQLite) ────────────────────────────────

  void _saveState() {
    if (_tutorialMode || _currentPuzzle == null || _gameWon) return;
    final state = SavedGameState(
      puzzle: _currentPuzzle!,
      grid: _grid.map((r) => List<String>.from(r)).toList(),
      swapCount: _swapCount,
      hintCount: _hintCount,
      totalSwapCount: _totalSwapCount,
      level: _currentLevel,
    );
    try {
      final jsonStr = jsonEncode(state.toJson());
      _gameStateRepo.upsert(GameStateModel(
        userId: _userId,
        level: _currentLevel,
        gridJson: jsonStr,
        swapsUsed: _swapCount,
      ));
    } catch (_) {}
  }

  Future<SavedGameState?> loadSavedState(int level) async {
    try {
      final model = await _gameStateRepo.getByUserAndLevel(_userId, level);
      if (model == null) return null;
      final json = jsonDecode(model.gridJson) as Map<String, dynamic>;
      return SavedGameState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  void clearSavedState() {
    _clearSavedState();
  }

  void _clearSavedState() {
    _gameStateRepo.clearState(_userId, _currentLevel);
    _prefs.remove('wordle7_hint_cooldown_end');
    _prefs.remove('wordle7_solve_cooldown_end');
  }

  /// Save level completion progress to database.
  Future<void> saveProgress(int level, {bool completed = true}) async {
    await _progressRepo.upsert(_userId, level, completed: completed);
  }

  /// Get the highest completed level from database.
  Future<int> getHighestCompletedLevel() async {
    return _progressRepo.getHighestCompletedLevel(_userId);
  }

  void clearLastSwap() {
    _lastSwap = null;
    notifyListeners();
  }

  // ── Internal helpers ─────────────────────────────────────

  void _buildCellToWords() {
    _cellToWords.clear();
    for (int wi = 0; wi < _wordList.length; wi++) {
      final w = _wordList[wi];
      for (int j = 0; j < w.word.length; j++) {
        final r = w.direction == WordDirection.horizontal ? w.row : w.row + j;
        final c = w.direction == WordDirection.horizontal ? w.col + j : w.col;
        final key = '$r,$c';
        _cellToWords.putIfAbsent(key, () => []).add(wi);
      }
    }
  }

  void _clearHintState() {
    _hintMessage = '';
    _hintCooldown = false;
    _hintCooldownRemaining = 0;
    _hintSwappedCells = [];
  }

  void _restoreCooldowns() {
    final now = DateTime.now().millisecondsSinceEpoch;

    final hintEnd = _prefs.getInt('wordle7_hint_cooldown_end') ?? 0;
    final hintRemaining = ((hintEnd - now) / 1000).ceil();
    if (hintRemaining > 0) {
      _hintCooldown = true;
      _hintCooldownRemaining = hintRemaining;
      _tickCooldown(
        getRemainingFn: () => _hintCooldownRemaining,
        setRemainingFn: (v) => _hintCooldownRemaining = v,
        setCooldownFn: (v) => _hintCooldown = v,
        prefKey: 'wordle7_hint_cooldown_end',
      );
    }

    final solveEnd = _prefs.getInt('wordle7_solve_cooldown_end') ?? 0;
    final solveRemaining = ((solveEnd - now) / 1000).ceil();
    if (solveRemaining > 0) {
      _solveWordCooldown = true;
      _solveWordCooldownRemaining = solveRemaining;
      _tickCooldown(
        getRemainingFn: () => _solveWordCooldownRemaining,
        setRemainingFn: (v) => _solveWordCooldownRemaining = v,
        setCooldownFn: (v) => _solveWordCooldown = v,
        prefKey: 'wordle7_solve_cooldown_end',
      );
    }
  }
}
