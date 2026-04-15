import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/repositories/daily_puzzle_repository.dart';
import '../database/repositories/daily_streak_repository.dart';
import '../database/models/daily_puzzle_model.dart';
import '../models/puzzle.dart';
import '../models/level_config.dart';
import 'puzzle_generator.dart';
import 'coin_service.dart';

/// Cost in coins to recover a broken streak.
const int streakRecoveryCost = 250;

/// Manages daily puzzle generation, grid persistence, and streak tracking.
///
/// Each day at 00:01 a new puzzle becomes available. The puzzle seed is
/// deterministic based on the date so every user gets the same layout.
/// Difficulty follows a 7-day repeating cycle (anchored to 2025-01-01):
///   days 0-2 = easy, days 3-4 = medium, days 5-6 = hard.
class DailyPuzzleService extends ChangeNotifier {
  final DailyPuzzleRepository _puzzleRepo;
  final DailyStreakRepository _streakRepo;
  final int _userId;

  bool _isLoaded = false;
  int _currentStreak = 0;
  int _bestStreak = 0;
  String? _lastSolvedDate;
  String? _frozenUntil;
  bool _isTodaySolved = false;

  DailyPuzzleService(this._puzzleRepo, this._streakRepo, this._userId);

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  bool get isLoaded => _isLoaded;
  bool get isTodaySolved => _isTodaySolved;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  String? get lastSolvedDate => _lastSolvedDate;
  int get recoveryCost => streakRecoveryCost;

  /// True when the user missed exactly one day (yesterday), the day before
  /// yesterday was the last solved date, and the current streak was > 0 before
  /// the miss. This is the only window in which recovery is allowed.
  bool get canRecoverStreak {
    if (_currentStreak <= 0) return false;
    if (_lastSolvedDate == null) return false;

    final today = _todayDate();
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBeforeYesterday = today.subtract(const Duration(days: 2));

    final lastSolved = _parseDate(_lastSolvedDate!);
    if (lastSolved == null) return false;

    // Last solved must be the day before yesterday (i.e. user missed yesterday).
    if (!_sameDay(lastSolved, dayBeforeYesterday)) return false;

    // If we already froze past yesterday, recovery is unnecessary.
    if (_frozenUntil != null) {
      final frozen = _parseDate(_frozenUntil!);
      if (frozen != null && !frozen.isBefore(yesterday)) return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Load streak data from the database. Call once after construction.
  Future<void> init() async {
    final streak = await _streakRepo.getOrCreate(_userId);
    _currentStreak = streak.currentStreak;
    _bestStreak = streak.bestStreak;
    _lastSolvedDate = streak.lastSolvedDate;
    _frozenUntil = streak.frozenUntil;

    // Check if today is already solved.
    final todayStr = _dateString(_todayDate());
    final todayPuzzle = await _puzzleRepo.getByUserAndDate(_userId, todayStr);
    _isTodaySolved = todayPuzzle != null && todayPuzzle.solved == 1;

    _isLoaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Puzzle lifecycle
  // ---------------------------------------------------------------------------

  /// Return today's puzzle, generating and persisting it if it doesn't exist.
  Future<Wordle7Puzzle?> getTodayPuzzle() async {
    final todayStr = _dateString(_todayDate());
    final existing = await _puzzleRepo.getByUserAndDate(_userId, todayStr);

    if (existing != null && existing.puzzleJson.isNotEmpty) {
      try {
        return Wordle7Puzzle.fromJson(
          jsonDecode(existing.puzzleJson) as Map<String, dynamic>,
        );
      } catch (_) {
        // Corrupted JSON — regenerate below.
      }
    }

    // Generate a new puzzle for today.
    final today = _todayDate();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final difficulty = _difficultyForDate(today);
    final puzzle = PuzzleGenerator.generateRandom(seed, difficulty: difficulty);

    await _puzzleRepo.upsert(
      _userId,
      todayStr,
      puzzleJson: jsonEncode(puzzle.toJson()),
    );

    return puzzle;
  }

  /// Persist the current grid state so the user can resume later.
  Future<void> saveGridState(
    List<List<String>> grid,
    int swapsUsed,
    int hintCount,
    int totalSwapCount,
  ) async {
    final todayStr = _dateString(_todayDate());
    final gridJson = jsonEncode(grid.map((r) => r.toList()).toList());

    await _puzzleRepo.upsert(
      _userId,
      todayStr,
      gridJson: gridJson,
      swapsUsed: swapsUsed,
      hintCount: hintCount,
      totalSwapCount: totalSwapCount,
    );
  }

  /// Mark today's puzzle as solved and update the streak.
  Future<void> markSolved() async {
    final today = _todayDate();
    final todayStr = _dateString(today);

    // Persist solve flag.
    await _puzzleRepo.upsert(_userId, todayStr, solved: true);

    // --- Streak logic ---
    if (_lastSolvedDate == todayStr) {
      // Already counted today — just refresh local state.
      _isTodaySolved = true;
      notifyListeners();
      return;
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final lastSolved = _lastSolvedDate != null ? _parseDate(_lastSolvedDate!) : null;

    int newStreak;
    if (lastSolved != null && _sameDay(lastSolved, yesterday)) {
      // Consecutive day — extend streak.
      newStreak = _currentStreak + 1;
    } else if (lastSolved != null && !_sameDay(lastSolved, today)) {
      // Missed at least one day — check freeze protection.
      if (_isStreakProtected(lastSolved, today)) {
        newStreak = _currentStreak + 1;
      } else {
        newStreak = 1;
      }
    } else {
      // First solve ever or same-day duplicate (handled above).
      newStreak = _currentStreak > 0 ? _currentStreak + 1 : 1;
    }

    final newBest = newStreak > _bestStreak ? newStreak : _bestStreak;

    await _streakRepo.updateStreak(
      _userId,
      currentStreak: newStreak,
      bestStreak: newBest,
      lastSolvedDate: todayStr,
    );

    _currentStreak = newStreak;
    _bestStreak = newBest;
    _lastSolvedDate = todayStr;
    _isTodaySolved = true;
    notifyListeners();
  }

  /// Recover a broken streak by spending coins. Returns true on success.
  ///
  /// Recovery is only available when the user missed exactly one day
  /// (yesterday) and the day before yesterday was their last solve.
  /// The cost is [streakRecoveryCost] coins. On success the streak freeze
  /// is set to yesterday so the next solve extends the streak normally.
  Future<bool> recoverStreak(CoinService coinService) async {
    if (!canRecoverStreak) return false;
    if (!coinService.canAfford(streakRecoveryCost)) return false;

    final yesterday = _todayDate().subtract(const Duration(days: 1));
    final yesterdayStr = _dateString(yesterday);

    if (!coinService.spend(streakRecoveryCost)) return false;

    await _streakRepo.setFrozenUntil(_userId, yesterdayStr);
    _frozenUntil = yesterdayStr;
    notifyListeners();
    return true;
  }

  /// Return the saved daily puzzle model (with grid state) for resuming.
  Future<DailyPuzzleModel?> getSavedState() async {
    final todayStr = _dateString(_todayDate());
    return _puzzleRepo.getByUserAndDate(_userId, todayStr);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// 7-day repeating cycle: 3 easy → 2 medium → 2 hard.
  /// Anchored to 2025-01-01 so the cycle is consistent across all devices.
  static Difficulty _difficultyForDate(DateTime date) {
    const cycle = [
      Difficulty.easy, Difficulty.easy, Difficulty.easy,
      Difficulty.medium, Difficulty.medium,
      Difficulty.hard, Difficulty.hard,
    ];
    final epoch = DateTime(2025, 1, 1);
    final dayIndex = date.difference(epoch).inDays % cycle.length;
    return cycle[dayIndex.abs()];
  }

  /// Check whether the streak is protected by a freeze between [lastSolved]
  /// and [today]. The freeze covers every missed day in between.
  bool _isStreakProtected(DateTime lastSolved, DateTime today) {
    if (_frozenUntil == null) return false;
    final frozen = _parseDate(_frozenUntil!);
    if (frozen == null) return false;

    // Every day between lastSolved (exclusive) and today (exclusive) must be
    // on or before the frozen-until date to be considered protected.
    var day = lastSolved.add(const Duration(days: 1));
    while (day.isBefore(today)) {
      if (frozen.isBefore(day)) return false;
      day = day.add(const Duration(days: 1));
    }
    return true;
  }

  /// Today's date with time stripped.
  static DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Format a [DateTime] as `yyyy-MM-dd`.
  static String _dateString(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Parse a `yyyy-MM-dd` string back into a date-only [DateTime].
  static DateTime? _parseDate(String s) {
    try {
      final parts = s.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      // Fallback: try ISO parse.
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  /// Compare two dates ignoring time components.
  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
