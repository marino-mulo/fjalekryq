import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// User Messaging Platform (UMP) consent flow.
///
/// Required by Google for any AdMob-monetized app whose users may be in
/// the EEA, UK, or Switzerland (Google's "Consent Mode v2" policy,
/// effective 2024). Without this, AdMob will eventually stop serving
/// ads to European users and Google can suspend the AdMob account.
///
/// Flow:
///   1. `requestConsentInfoUpdate` — fetch the latest consent state
///      from Google. Includes the user's geo and any existing TCF
///      consent string.
///   2. If a form is required (`isConsentFormAvailable`), show it.
///   3. Whether the user accepted, rejected, or the form wasn't
///      required, return — the caller (`main`) can now safely call
///      `MobileAds.initialize`. AdMob will internally honor whatever
///      consent state the SDK gathered.
///
/// On Android non-EEA users this is essentially a no-op (the form is
/// not required and the call returns immediately).
class ConsentService {
  ConsentService._();

  /// Gather UMP consent. Always returns — never throws — so the boot
  /// sequence cannot be blocked by a UMP failure. On error we proceed
  /// to AdMob init with whatever state UMP managed to capture; the SDK
  /// is conservative by default (treats the user as non-consented).
  static Future<void> gather() async {
    final completer = Completer<void>();

    // The default ConsentRequestParameters use the device's geo
    // (Google decides whether the form is required). For testing in
    // a non-EEA region, you can force the EEA flow with
    // `ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea)`.
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          final available =
              await ConsentInformation.instance.isConsentFormAvailable();
          if (!available) {
            if (!completer.isCompleted) completer.complete();
            return;
          }
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint('UMP: form error ${formError.errorCode} '
                  '${formError.message}');
            }
            if (!completer.isCompleted) completer.complete();
          });
        } catch (e) {
          debugPrint('UMP: post-update error: $e');
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) {
        debugPrint('UMP: requestConsentInfoUpdate error '
            '${error.errorCode} ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    // Hard cap so the splash never hangs if UMP gets stuck behind a
    // flaky network. AdMob will gracefully serve non-personalized ads
    // when no consent has been gathered.
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint('UMP: gather timed out — proceeding without consent');
      },
    );
  }

  /// Re-show the consent form on demand (e.g. from Settings →
  /// "Privacy preferences"). Required by both Apple and Google: users
  /// must be able to change their mind at any time.
  static Future<void> reshow() async {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((formError) {
      if (formError != null) {
        debugPrint('UMP: reshow error ${formError.errorCode} '
            '${formError.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  /// Wipe the cached UMP consent (debug only). Useful for re-testing
  /// the form after you've already accepted once.
  static void resetForTesting() {
    if (!kDebugMode) return;
    ConsentInformation.instance.reset();
  }
}
