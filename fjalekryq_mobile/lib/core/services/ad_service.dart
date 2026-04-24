import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../database/repositories/ad_reward_repository.dart';
import 'connectivity_service.dart';

/// Ad reward types used for daily limit tracking.
class AdType {
  static const String dailyDouble = 'daily_double';
  static const String freeSolve = 'free_solve';
  static const String freeHint = 'free_hint';
  static const String bonusCoins = 'bonus_coins';
  static const String continueAfterLoss = 'continue_loss';
  static const String doubleWinCoins = 'double_win';
}

/// Daily limits per ad type.
const Map<String, int> adDailyLimits = {
  AdType.dailyDouble: 5,
  AdType.freeSolve: 5,
  AdType.freeHint: 10,
  AdType.bonusCoins: 5,
  AdType.continueAfterLoss: 5,
  AdType.doubleWinCoins: 5,
};

const String _removeAdsKey = 'fjalekryq_remove_ads';
const String _levelCompletionCountKey = 'fjalekryq_level_completions';

/// Show an interstitial every N level completions.
const int _interstitialEveryN = 3;

/// Manages all ad types: rewarded, banner, and interstitial.
///
/// Remove Ads: once purchased, banners and interstitials are suppressed.
/// Rewarded ads (user-initiated) remain available even after purchasing
/// "Remove Ads", consistent with the Easybrain monetization model.
class AdService extends ChangeNotifier {
  final AdRewardRepository _adRewardRepo;
  final int _userId;
  final SharedPreferences _prefs;

  AdService(this._adRewardRepo, this._userId, this._prefs);

  // ── Remove Ads ────────────────────────────────────────────────────────────

  bool get removeAds => _prefs.getBool(_removeAdsKey) ?? false;

  /// Purchase "Remove Ads". In dev: instant success. In prod: TODO real IAP.
  ///
  /// Replace the prod branch with your in_app_purchase flow before shipping.
  Future<bool> purchaseRemoveAds() async {
    if (removeAds) return true;
    if (AppConfig.isDev) {
      await Future.delayed(const Duration(milliseconds: 600));
    }
    // TODO (prod): call real in_app_purchase flow here and only proceed on
    // confirmed receipt. Until then this grants free removal for testing.
    await _prefs.setBool(_removeAdsKey, true);
    _disposeBanner();
    _disposeInterstitial();
    notifyListeners();
    return true;
  }

  // ── Banner Ad ─────────────────────────────────────────────────────────────

  BannerAd? _bannerAd;
  bool _bannerReady = false;

  /// True when a banner is loaded and "Remove Ads" has not been purchased.
  bool get bannerReady => _bannerReady && !removeAds;

  /// The loaded banner, or null if not ready.
  BannerAd? get bannerAd => bannerReady ? _bannerAd : null;

  /// Load a banner for the game screen. No-op if ads are removed.
  void loadBanner() {
    if (removeAds) return;
    _bannerAd?.dispose();
    _bannerReady = false;

    final adUnitId = Platform.isAndroid
        ? AppConfig.bannerAdUnitAndroid
        : AppConfig.bannerAdUnitIos;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _bannerReady = false;
          debugPrint('AdMob: banner failed to load: $error');
        },
      ),
    )..load();
  }

  /// Dispose the banner. Call from the host widget's dispose().
  void disposeBanner() => _disposeBanner();

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerReady = false;
  }

  // ── Interstitial Ad ───────────────────────────────────────────────────────

  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;

  /// Preload an interstitial so it is ready for the next level transition.
  /// No-op if ads are removed or an ad is already loaded/loading.
  void preloadInterstitial() {
    if (removeAds || _interstitialReady) return;

    final adUnitId = Platform.isAndroid
        ? AppConfig.interstitialAdUnitAndroid
        : AppConfig.interstitialAdUnitIos;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
        },
        onAdFailedToLoad: (error) {
          _interstitialReady = false;
          debugPrint('AdMob: interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Show an interstitial if the frequency cap allows it (every 3 completions).
  ///
  /// Always increments the completion counter. Returns true if an ad was shown.
  Future<bool> showInterstitialIfDue() async {
    if (removeAds) return false;

    final count = (_prefs.getInt(_levelCompletionCountKey) ?? 0) + 1;
    await _prefs.setInt(_levelCompletionCountKey, count);

    if (count % _interstitialEveryN != 0) return false;

    if (!_interstitialReady || _interstitialAd == null) {
      preloadInterstitial();
      return false;
    }

    final completer = Completer<bool>();
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialReady = false;
        if (!completer.isCompleted) completer.complete(true);
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialReady = false;
        debugPrint('AdMob: interstitial failed to show: $error');
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    _interstitialAd!.show();
    return completer.future;
  }

  void _disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialReady = false;
  }

  /// Fire a rewarded ad on the same cadence as the interstitial (every
  /// N level completions) so the rewarded-ad path is exercised in the
  /// same natural test loop. Call this *after* [showInterstitialIfDue]
  /// in the level-transition flow — it reads the counter the
  /// interstitial just updated, so both trigger on the same clear
  /// without double-incrementing.
  ///
  /// Uses [AdType.bonusCoins] so the normal daily-limit cap still
  /// applies. [onReward] is invoked on a successful watch; a small
  /// bonus (e.g. 10 coins) is the usual reward, but callers pick.
  Future<bool> showRewardedIfDue({
    required Future<void> Function() onReward,
    void Function()? onOffline,
  }) async {
    if (removeAds) return false;
    final count = _prefs.getInt(_levelCompletionCountKey) ?? 0;
    if (count == 0 || count % _interstitialEveryN != 0) return false;
    return showRewardedAd(
      adType: AdType.bonusCoins,
      onReward: onReward,
      onOffline: onOffline,
    );
  }

  // ── Rewarded Ad ────────────────────────────────────────────────────────────

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
    final limit = adDailyLimits[adType] ?? 3;
    final claimedToday = await _adRewardRepo.claimedTodayCount(_userId, adType);
    if (claimedToday >= limit) return false;

    final bool rewarded;
    if (AppConfig.isDev) {
      await Future.delayed(const Duration(milliseconds: 1500));
      rewarded = true;
    } else {
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

  // ── Real AdMob rewarded implementation (prod only) ────────────────────────

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
