import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/repositories/ad_reward_repository.dart';

/// Ad reward types used for daily limit tracking.
class AdType {
  static const String dailyDouble = 'daily_double';
  static const String freeSolve = 'free_solve';
  static const String bonusCoins = 'bonus_coins';
  static const String continueAfterLoss = 'continue_loss';
  static const String doubleWinCoins = 'double_win';
}

/// Daily limits per ad type.
const Map<String, int> adDailyLimits = {
  AdType.dailyDouble: 5,
  AdType.freeSolve: 5,
  AdType.bonusCoins: 5,
  AdType.continueAfterLoss: 5,
  AdType.doubleWinCoins: 5,
};

/// Manages rewarded ad display and tracking.
/// Currently uses a placeholder/test mode that simulates watching an ad.
/// Replace the [showRewardedAd] body with real google_mobile_ads when ready.
class AdService extends ChangeNotifier {
  final AdRewardRepository _adRewardRepo;
  final int _userId;

  AdService(this._adRewardRepo, this._userId);

  /// Show a rewarded ad. Returns true if reward was granted.
  /// In placeholder mode, simulates a 1.5-second ad viewing delay.
  Future<bool> showRewardedAd({
    required String adType,
    required Future<void> Function() onReward,
  }) async {
    // Check daily limit
    final limit = adDailyLimits[adType] ?? 3;
    final claimedToday = await _adRewardRepo.claimedTodayCount(_userId, adType);
    if (claimedToday >= limit) return false;

    // --- Placeholder: simulate ad viewing ---
    // In production, replace this block with:
    //   final ad = await RewardedAd.load(...);
    //   final completer = Completer<bool>();
    //   ad.show(onUserEarnedReward: (_, __) { completer.complete(true); });
    //   return completer.future;
    await Future.delayed(const Duration(milliseconds: 1500));

    // Record the claim
    await _adRewardRepo.claim(_userId, adType);

    // Grant the reward
    await onReward();

    notifyListeners();
    return true;
  }

  /// Check if the user can still watch an ad of this type today.
  Future<bool> canWatch(String adType) async {
    final limit = adDailyLimits[adType] ?? 3;
    final claimedToday = await _adRewardRepo.claimedTodayCount(_userId, adType);
    return claimedToday < limit;
  }

  /// How many times the user has watched this ad type today.
  Future<int> watchedToday(String adType) async {
    return _adRewardRepo.claimedTodayCount(_userId, adType);
  }

  /// Remaining watches for this ad type today.
  Future<int> remainingToday(String adType) async {
    final limit = adDailyLimits[adType] ?? 3;
    final claimedToday = await _adRewardRepo.claimedTodayCount(_userId, adType);
    return (limit - claimedToday).clamp(0, limit);
  }
}
