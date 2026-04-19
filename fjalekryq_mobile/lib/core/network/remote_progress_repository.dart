import '../database/models/progress_model.dart';
import 'api_client.dart';

/// Remote implementation mirroring [ProgressRepository]'s public interface.
class RemoteProgressRepository {
  Future<ProgressModel?> getByUserAndLevel(int userId, int level) async {
    final data = await ApiClient.get('/progress');
    final levels = (data['levels'] as List<dynamic>? ?? []);
    final match = levels.cast<Map<String, dynamic>>()
        .where((l) => (l['level'] as int?) == level)
        .firstOrNull;
    if (match == null) return null;
    return ProgressModel(
      userId:    userId,
      level:     match['level']     as int,
      stars:     match['stars']     as int? ?? 0,
      completed: (match['completed'] as bool? ?? false) ? 1 : 0,
    );
  }

  Future<int> getHighestCompletedLevel(int userId) async {
    final data = await ApiClient.get('/progress');
    return (data['highestCompletedLevel'] as int?) ?? 0;
  }

  Future<int> getCompletedCount(int userId) async {
    final data = await ApiClient.get('/progress');
    final levels = (data['levels'] as List<dynamic>? ?? []);
    return levels.cast<Map<String, dynamic>>()
        .where((l) => l['completed'] == true)
        .length;
  }

  Future<int> getTotalStars(int userId) async {
    final data = await ApiClient.get('/progress');
    return (data['totalStars'] as int?) ?? 0;
  }

  /// Upsert is called by the service layer when a level is completed.
  Future<void> upsert(int userId, int level, {int? stars, bool? completed}) async {
    if (completed == true) {
      await ApiClient.postVoid('/progress/$level', body: {
        'stars': stars ?? 0,
      });
    }
  }
}
