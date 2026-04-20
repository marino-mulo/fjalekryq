/// Central environment configuration.
///
/// Set the environment at build/run time with:
///   flutter run  --dart-define=ENVIRONMENT=dev    (default)
///   flutter run  --dart-define=ENVIRONMENT=prod
///   flutter build apk --dart-define=ENVIRONMENT=prod
///   flutter build ipa --dart-define=ENVIRONMENT=prod
class AppConfig {
  AppConfig._();

  static const String _env =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

  static bool get isDev => _env != 'prod';
  static bool get isProd => _env == 'prod';

  // ── Database ──────────────────────────────────────────────────────────────
  /// SQLite file name. Dev uses a separate DB so prod data is never touched.
  static String get databaseName =>
      isProd ? 'fjalekryq.db' : 'fjalekryq_dev.db';

  // ── AdMob ─────────────────────────────────────────────────────────────────
  // Dev  → Google's official test IDs (safe to commit, never generate real charges).
  // Prod → Replace YOUR_* placeholders with real IDs from the AdMob console
  //        (https://admob.google.com) before submitting to the stores.

  /// AdMob Application ID — Android.
  /// Also set in build.gradle.kts manifestPlaceholders (required by Android).
  static String get admobAppIdAndroid => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID~YOUR_APP_ID_ANDROID' // ← replace
      : 'ca-app-pub-3940256099942544~3347511713'; // Google test app ID

  /// AdMob Application ID — iOS.
  /// Also set in ios/Runner/Info.plist (required by iOS).
  static String get admobAppIdIos => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID~YOUR_APP_ID_IOS' // ← replace
      : 'ca-app-pub-3940256099942544~1458002511'; // Google test app ID

  /// Rewarded ad unit ID — Android.
  /// One unit covers all in-game rewarded placements; add more if AdMob requires
  /// separate units per placement.
  static String get rewardedAdUnitAndroid => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID/YOUR_REWARDED_UNIT_ANDROID' // ← replace
      : 'ca-app-pub-3940256099942544/5224354917'; // Google test rewarded unit

  /// Rewarded ad unit ID — iOS.
  static String get rewardedAdUnitIos => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID/YOUR_REWARDED_UNIT_IOS' // ← replace
      : 'ca-app-pub-3940256099942544/1712485313'; // Google test rewarded unit

  /// Banner ad unit ID — Android.
  static String get bannerAdUnitAndroid => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID/YOUR_BANNER_UNIT_ANDROID' // ← replace
      : 'ca-app-pub-3940256099942544/6300978111'; // Google test banner unit

  /// Banner ad unit ID — iOS.
  static String get bannerAdUnitIos => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID/YOUR_BANNER_UNIT_IOS' // ← replace
      : 'ca-app-pub-3940256099942544/2934735716'; // Google test banner unit

  /// Interstitial ad unit ID — Android.
  /// Shown at natural level-transition break points with a frequency cap.
  static String get interstitialAdUnitAndroid => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID/YOUR_INTERSTITIAL_UNIT_ANDROID' // ← replace
      : 'ca-app-pub-3940256099942544/1033173712'; // Google test interstitial unit

  /// Interstitial ad unit ID — iOS.
  static String get interstitialAdUnitIos => isProd
      ? 'ca-app-pub-YOUR_PUBLISHER_ID/YOUR_INTERSTITIAL_UNIT_IOS' // ← replace
      : 'ca-app-pub-3940256099942544/4411468910'; // Google test interstitial unit

  /// Price shown to users for the "Remove Ads" in-app purchase.
  /// Replace with the real price from your App Store / Play Store product.
  static const String removeAdsPriceLabel = '\$4.99';

  // ── API / Backend (future) ────────────────────────────────────────────────
  /// Base URL for the backend REST API.
  /// 10.0.2.2 is the Android emulator's alias for host-machine localhost.
  /// For a physical dev device, replace with your machine's LAN IP.
  static String get apiBaseUrl => isProd
      ? 'https://api.fjalekryq.com' // ← replace with real domain
      : 'http://10.0.2.2:3000/api';

  // ── Feature flags ─────────────────────────────────────────────────────────
  /// Show the Flutter debug banner only in dev.
  static bool get showDebugBanner => isDev;

  /// Log verbose output only in dev.
  static bool get verboseLogging => isDev;
}
