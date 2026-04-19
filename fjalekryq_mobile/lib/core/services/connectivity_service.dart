import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Lightweight reactive connectivity probe. Avoids adding a plugin
/// dependency — does a DNS lookup (fast, cached by the OS) and treats
/// any failure / timeout as "offline".
///
/// Two APIs are offered:
///
///   1. `ConnectivityService.hasInternet()` (static) — one-shot Boolean
///      check for imperative callers (e.g. "before I kick off the ad
///      load, am I online?").
///
///   2. `ConnectivityService()` (singleton ChangeNotifier) — reactive
///      state for the UI. Provider-wrap it and use `context.watch` to
///      rebuild buttons / banners the moment connectivity flips, no
///      app restart needed.
///
/// The singleton polls every 5 s in the background and also exposes
/// `recheck()` so call sites can nudge the probe after a network error
/// (e.g. a failed API call) for a near-instant UI update.
class ConnectivityService extends ChangeNotifier {
  // ── Singleton ───────────────────────────────────────────────────────
  static final ConnectivityService instance = ConnectivityService._internal();
  factory ConnectivityService() => instance;
  ConnectivityService._internal() {
    _start();
  }

  static const _probeHost   = 'google.com';
  static const _timeout     = Duration(seconds: 3);
  static const _pollInterval = Duration(seconds: 5);

  bool _isOnline = true; // optimistic start — first probe fires immediately
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  Timer? _timer;
  bool _probing = false;

  void _start() {
    // Fire once right away so the initial state reflects reality, then
    // poll on a fixed cadence.
    _probe();
    _timer = Timer.periodic(_pollInterval, (_) => _probe());
  }

  /// Force an immediate re-check. Useful after an API call fails so the
  /// UI can flip to "offline" without waiting for the next poll.
  Future<void> recheck() => _probe();

  Future<void> _probe() async {
    if (_probing) return;
    _probing = true;
    try {
      final online = await _rawCheck();
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    } finally {
      _probing = false;
    }
  }

  static Future<bool> _rawCheck() async {
    try {
      final result =
          await InternetAddress.lookup(_probeHost).timeout(_timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  // ── Static one-shot check (backwards compatible) ───────────────────
  /// Returns `true` when a DNS lookup succeeds within 3 s. Never throws.
  /// Also nudges the singleton so its cached `isOnline` updates.
  static Future<bool> hasInternet() async {
    final online = await _rawCheck();
    if (instance._isOnline != online) {
      instance._isOnline = online;
      instance.notifyListeners();
    }
    return online;
  }
}
