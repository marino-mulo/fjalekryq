import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_token_store.dart';

/// Wraps [http.Client] with:
///   - Automatic Bearer token attachment
///   - 401 → refresh → retry once
///   - Throws [ApiException] for non-2xx responses
class ApiClient {
  ApiClient._();

  static final _client = http.Client();

  // ── Public methods ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> get(String path) async {
    return _requestJson('GET', path);
  }

  /// GET endpoint whose response body is a top-level JSON array (e.g.
  /// `/leaderboard/*`). Returns the decoded list unchanged so callers
  /// can cast the elements themselves.
  static Future<List<dynamic>> getList(String path) async {
    final response = await _request('GET', path);
    final decoded  = jsonDecode(response.body);
    return decoded is List ? decoded : <dynamic>[];
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _requestJson('POST', path, body: body);
  }

  static Future<void> postVoid(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _request('POST', path, body: body);
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _request(method, path, body: body);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    // If the app went online after a failed startup bootstrap, no token
    // will exist yet. Lazily create a guest session so downstream
    // protected endpoints (leaderboard, coins, progress…) just work.
    // We skip this for /auth/* calls to avoid recursing into ourselves.
    if (!path.startsWith('/auth/') && !await AuthTokenStore.isLoggedIn()) {
      try {
        final data = await _requestJson(
          'POST',
          '/auth/guest',
        );
        await AuthTokenStore.save(
          accessToken:  data['accessToken']  as String,
          refreshToken: data['refreshToken'] as String,
          userId:       data['userId']       as int,
        );
      } catch (_) {
        // Swallow: let the real request fail with its own error so the
        // UI offline handling kicks in the same way as before.
      }
    }

    final token   = await AuthTokenStore.getAccessToken();
    final headers = _buildHeaders(token);
    final uri     = Uri.parse('${AppConfig.apiBaseUrl}$path');

    http.Response response;
    const timeout = Duration(seconds: 8);
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        response = await _client.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(timeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    // 401 → try to refresh once, then retry. Tokens are effectively
    // permanent server-side now, so a failed refresh is almost always a
    // transient / network blip rather than a truly invalidated session.
    // Don't clear tokens or bounce the user to a login screen — let the
    // call surface a normal ApiException so the UI can show a soft toast
    // and the user keeps playing.
    if (response.statusCode == 401 && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(method, path, body: body, isRetry: true);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        message = decoded?['error'] as String?;
      } catch (_) {}
      throw ApiException(response.statusCode, message ?? response.reasonPhrase ?? 'Request failed');
    }

    return response;
  }

  static Map<String, String> _buildHeaders(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Returns true if the token was refreshed successfully.
  static Future<bool> _tryRefresh() async {
    final refreshToken = await AuthTokenStore.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final uri      = Uri.parse('${AppConfig.apiBaseUrl}/auth/refresh');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await AuthTokenStore.save(
        accessToken:  data['accessToken']  as String,
        refreshToken: data['refreshToken'] as String,
        userId:       data['userId']       as int,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final int    statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
