import 'package:flutter/foundation.dart';
import '../database/repositories/coins_repository.dart';
import '../database/models/coins_model.dart';

const int startingCoins = 100;
const int hintCost = 10;
const int solveCost = 50;

const List<int> dailyRewards = [20, 30, 45, 60, 80, 100, 125];

/// Manages the coin balance, spending, earning, and daily rewards.
/// Now backed by SQLite via CoinsRepository.
class CoinService extends ChangeNotifier {
  final CoinsRepository _repo;
  final int _userId;

  int _coins = 0;
  String? _lastDailyClaim;
  int _streakDay = 0;
  int? _recordId;

  CoinService(this._repo, this._userId);

  int get coins => _coins;

  /// Load coin data from database. Must be called after construction.
  Future<void> init() async {
    final model = await _repo.getOrCreate(_userId);
    _coins = model.balance;
    _lastDailyClaim = model.lastDailyClaim;
    _streakDay = model.streakDay;
    _recordId = model.id;
    notifyListeners();
  }

  bool canAfford(int amount) => _coins >= amount;

  void add(int amount) {
    _coins += amount;
    _save();
    notifyListeners();
  }

  bool spend(int amount) {
    if (!canAfford(amount)) return false;
    _coins -= amount;
    _save();
    notifyListeners();
    return true;
  }

  /// Check if today's reward is available without claiming it.
  ({int amount, int day})? peekDaily() {
    final today = _todayString();
    if (_lastDailyClaim == today) return null;

    final yesterday = _yesterdayString();
    final newStreak = (_lastDailyClaim == yesterday) ? (_streakDay % 7) + 1 : 1;
    return (amount: dailyRewards[newStreak - 1], day: newStreak);
  }

  /// Current claimed streak day (1-7).
  int get currentStreakDay {
    return _streakDay < 1 ? 1 : _streakDay;
  }

  /// Claim today's reward. Returns reward info or null if already claimed.
  ({int amount, int day})? claimDaily() {
    final today = _todayString();
    if (_lastDailyClaim == today) return null;

    final yesterday = _yesterdayString();
    final newStreak = (_lastDailyClaim == yesterday) ? (_streakDay % 7) + 1 : 1;

    _lastDailyClaim = today;
    _streakDay = newStreak;

    final amount = dailyRewards[newStreak - 1];
    _coins += amount;
    _saveDailyClaim();
    notifyListeners();
    return (amount: amount, day: newStreak);
  }

  void _save() {
    _repo.updateBalance(_userId, _coins);
  }

  void _saveDailyClaim() {
    _repo.updateDailyClaim(_userId, _lastDailyClaim!, _streakDay, _coins);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  String _yesterdayString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month}-${yesterday.day}';
  }
}
