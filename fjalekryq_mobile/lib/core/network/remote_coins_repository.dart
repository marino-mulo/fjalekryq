import 'api_client.dart';

/// Thin wrapper around the /coins endpoints.
class RemoteCoinsRepository {
  /// Pushes the local balance to the server. The server reconciles and
  /// returns its authoritative view, which callers should use to update
  /// their local cache. Throws on network / API failure.
  Future<int> syncBalance(int balance) async {
    final data = await ApiClient.post(
      '/coins/sync',
      body: {'balance': balance},
    );
    return (data['balance'] as int?) ?? balance;
  }

  Future<int> getBalance() async {
    final data = await ApiClient.get('/coins');
    return (data['balance'] as int?) ?? 0;
  }
}
