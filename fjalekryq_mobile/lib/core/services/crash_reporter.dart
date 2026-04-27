import 'dart:async';
import 'package:flutter/foundation.dart';

/// Centralized crash & error reporter.
///
/// This is a thin abstraction so the rest of the app can call
/// `CrashReporter.recordError(...)` without caring which backend (if
/// any) is wired in. Today it just logs to the console; once you have
/// a Sentry / Firebase Crashlytics account, plug it in inside the
/// methods below.
///
/// Wiring instructions are intentionally not committed as a real
/// dependency so the build doesn't fail without a DSN. To enable
/// Sentry:
///   1. Add `sentry_flutter: ^8.0.0` to pubspec.yaml
///   2. Set [_sentryDsn] below to your DSN.
///   3. In [init], replace the no-op with:
///        await SentryFlutter.init((o) => o
///          ..dsn = _sentryDsn
///          ..tracesSampleRate = 0.1);
///   4. In [recordError], call:
///        await Sentry.captureException(error, stackTrace: stack);
///
/// For Firebase Crashlytics, swap the imports for `firebase_crashlytics`
/// and replace the same two call sites.
class CrashReporter {
  CrashReporter._();

  // ignore: unused_field
  static const String _sentryDsn = ''; // ← paste DSN here when ready

  static bool _initialized = false;

  /// Wire up global error handlers. Call once from `main` before
  /// `runApp`. Safe to call without a backend configured — it will
  /// just route uncaught errors to debugPrint.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Catch synchronous Flutter framework errors.
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      priorOnError?.call(details);
      recordError(details.exception, details.stack ?? StackTrace.empty,
          context: 'FlutterError');
    };

    // Catch errors that escape the framework (raw isolate errors).
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, context: 'PlatformDispatcher');
      return true;
    };

    // TODO: when Sentry is wired in, init it here.
  }

  /// Record an error. Non-blocking — fire and forget from call sites
  /// (they shouldn't await crash reporting).
  static void recordError(
    Object error,
    StackTrace stack, {
    String? context,
  }) {
    if (kDebugMode) {
      debugPrint('▶ CrashReporter [$context]: $error');
      debugPrint(stack.toString());
    }
    // TODO: when Sentry is wired in, forward here.
    // unawaited(Sentry.captureException(error, stackTrace: stack));
  }

  /// Wrap an async block so any error gets recorded and rethrown.
  static Future<T> guard<T>(
    Future<T> Function() body, {
    String? context,
  }) async {
    try {
      return await body();
    } catch (e, s) {
      recordError(e, s, context: context);
      rethrow;
    }
  }
}
