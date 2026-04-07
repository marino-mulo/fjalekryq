import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _coinsKey = 'fjalekryq_coins';
const String _lastLoginKey = 'fjalekryq_last_login';
const String _streakKey = 'fjalekryq_login_streak';

const int startingCoins = 100;
const int hintCost = 10;
const int solveCost = 50;

const List<int> dailyRewards = [20, 30, 45, 60, 80, 100, 125];

/// Manages the coin balance, spending, earning, and daily rewards.
/// Ported from coin.service.ts
class CoinService extends ChangeNotifier {
  final SharedPreferences _prefs;
  int _coins = 0;

  CoinService(this._prefs) {
    final stored = _prefs.getInt(_coinsKey);
    if (stored == null) {
      _coins = startingCoins;
      _save();
    } else {
      _coins = stored < 0 ? 0 : stored;
    }
  }

  int get coins => _coins;

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
    if (_prefs.getString(_lastLoginKey) == today) return null;

    final yesterday = _yesterdayString();
    final lastLogin = _prefs.getString(_lastLoginKey);
    final streak = _prefs.getInt(_streakKey) ?? 0;
    final newStreak = (lastLogin == yesterday) ? (streak % 7) + 1 : 1;
    return (amount: dailyRewards[newStreak - 1], day: newStreak);
  }

  /// Current claimed streak day (1-7).
  int get currentStreakDay {
    final s = _prefs.getInt(_streakKey) ?? 1;
    return s < 1 ? 1 : s;
  }

  /// Claim today's reward. Returns reward info or null if already claimed.
  ({int amount, int day})? claimDaily() {
    final today = _todayString();
    final lastLogin = _prefs.getString(_lastLoginKey);
    if (lastLogin == today) return null;

    final yesterday = _yesterdayString();
    final streak = _prefs.getInt(_streakKey) ?? 0;
    final newStreak = (lastLogin == yesterday) ? (streak % 7) + 1 : 1;

    _prefs.setString(_lastLoginKey, today);
    _prefs.setInt(_streakKey, newStreak);

    final amount = dailyRewards[newStreak - 1];
    add(amount);
    return (amount: amount, day: newStreak);
  }

  void _save() {
    _prefs.setInt(_coinsKey, _coins);
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
