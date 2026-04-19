import 'api_client.dart';
import 'auth_token_store.dart';

/// Thin wrapper around the `/auth/*` endpoints. The OAuth flows are
/// invoked by the future login screen; the guest flow runs
/// automatically on first launch so the user can hit every protected
/// endpoint (leaderboard, coins, progress, …) without signing in.
class RemoteAuthRepository {
  /// Create a fresh guest account on the API and persist the token pair
  /// to [AuthTokenStore]. Safe to call in a fire-and-forget manner —
  /// idempotency is handled by the caller (check `isLoggedIn()` first).
  Future<void> loginAsGuest() async {
    final data = await ApiClient.post('/auth/guest');

    await AuthTokenStore.save(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
      userId:       data['userId']       as int,
    );
  }

  /// Ensure there is a valid session. If the user already has tokens,
  /// this is a no-op. Otherwise a guest account is created transparently.
  ///
  /// Returns true if a session is now available, false if the bootstrap
  /// call failed (offline, API down). Callers should tolerate `false`
  /// and let downstream requests surface the same "no internet" UI they
  /// already show for other API failures.
  Future<bool> ensureSession() async {
    if (await AuthTokenStore.isLoggedIn()) return true;
    try {
      await loginAsGuest();
      return true;
    } catch (_) {
      return false;
    }
  }
}
