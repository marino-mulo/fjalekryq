import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
import '../database/repositories/ad_reward_repository.dart';
import 'connectivity_service.dart';

/// Ad reward types used for daily limit tracking.
class AdType {
  static const String dailyDouble = 'daily_double';
  static const String freeSolve = 'free_solve';
  static const String bonusCoins = 'bonus_coins';
  static const String continueAfterLoss = 'continue_loss';
  static const String doubleWinCoins = 'double_win';

  /// Shown on win with < 3 stars — watch ad to replay the level.
  static const String playAgainFor3Stars = 'play_again_3stars';
}

/// Daily limits per ad type.
const Map<String, int> adDailyLimits = {
  AdType.dailyDouble: 5,
  AdType.freeSolve: 5,
  AdType.bonusCoins: 5,
  AdType.continueAfterLoss: 5,
  AdType.doubleWinCoins: 5,
  AdType.playAgainFor3Stars: 3,
};

/// Manages rewarded ad display and daily limit tracking.
///
/// In dev  → simulates a 1.5-second ad viewing delay (no real network calls).
/// In prod → loads and shows a real Google AdMob rewarded ad.
class AdService extends ChangeNotifier {
  final AdRewardRepository _adRewardRepo;
  final int _userId;

  AdService(this._adRewardRepo, this._userId);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Show a rewarded ad. Returns true if reward was granted.
  ///
  /// [onOffline] is invoked (and `false` is returned immediately) when we
  /// detect the device has no internet — only meaningful in production
  /// since dev mode simulates ads offline. Callers use it to surface an
  /// "internet needed" toast without caring about the ad loader internals.
  Future<bool> showRewardedAd({
    required String adType,
    required Future<void> Function() onReward,
    void Function()? onOffline,
  }) async {
    // Enforce daily limit regardless of environment
    final limit = adDailyLimits[adType] ?? 3;
    final claimedToday = await _adRewardRepo.claimedTodayCount(_userId, adType);
    if (claimedToday >= limit) return false;

    final bool rewarded;
    if (AppConfig.isDev) {
      // Dev: simulate ad with a short delay
      await Future.delayed(const Duration(milliseconds: 1500));
      rewarded = true;
    } else {
      // Prod: need internet for the real ad to load. Bail early with a
      // callback so the UI can toast the user instead of silently failing.
      if (!await ConnectivityService.hasInternet()) {
        onOffline?.call();
        return false;
      }
      rewarded = await _showRealRewardedAd();
    }

    if (!rewarded) return false;

    await _adRewardRepo.claim(_userId, adType);
    await onReward();
    notifyListeners();
    return true;
  }

  /// Whether the user can still watch an ad of this type today.
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

  // ── Real AdMob implementation (prod only) ─────────────────────────────────

  Future<bool> _showRealRewardedAd() async {
    final adUnitId = Platform.isAndroid
        ? AppConfig.rewardedAdUnitAndroid
        : AppConfig.rewardedAdUnitIos;

    final completer = Completer<bool>();

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              // User closed ad without earning reward — complete(false) only
              // if reward wasn't already granted
              if (!completer.isCompleted) completer.complete(false);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              debugPrint('AdMob: failed to show rewarded ad: $error');
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (_, reward) {
              if (!completer.isCompleted) completer.complete(true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdMob: failed to load rewarded ad: $error');
          completer.complete(false);
        },
      ),
    );

    return completer.future;
  }
}
