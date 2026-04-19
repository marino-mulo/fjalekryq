import 'package:shared_preferences/shared_preferences.dart';

/// Stores and retrieves JWT access + refresh tokens.
///
/// Backed by [SharedPreferences] — lightweight and already a project
/// dependency. (The original implementation used `flutter_secure_storage`
/// for Keychain/Keystore-backed storage; we dropped that to avoid adding
/// a native plugin. Swap back in if stricter at-rest protection is
/// required for tokens.)
class AuthTokenStore {
  AuthTokenStore._();

  static const _keyAccess  = 'fjalekryq_access_token';
  static const _keyRefresh = 'fjalekryq_refresh_token';
  static const _keyUserId  = 'fjalekryq_user_id';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int    userId,
  }) async {
    final p = await _prefs;
    await Future.wait<bool>([
      p.setString(_keyAccess,  accessToken),
      p.setString(_keyRefresh, refreshToken),
      p.setString(_keyUserId,  userId.toString()),
    ]);
  }

  static Future<String?> getAccessToken()  async =>
      (await _prefs).getString(_keyAccess);

  static Future<String?> getRefreshToken() async =>
      (await _prefs).getString(_keyRefresh);

  static Future<int?> getUserId() async {
    final s = (await _prefs).getString(_keyUserId);
    return s != null ? int.tryParse(s) : null;
  }

  static Future<bool> isLoggedIn() async =>
      (await _prefs).getString(_keyAccess) != null;

  static Future<void> clear() async {
    final p = await _prefs;
    await Future.wait<bool>([
      p.remove(_keyAccess),
      p.remove(_keyRefresh),
      p.remove(_keyUserId),
    ]);
  }
}
