import '../database/models/daily_puzzle_model.dart';
import '../database/repositories/daily_puzzle_repository.dart';
import 'api_client.dart';

/// Remote implementation of [DailyPuzzleRepository].
///
/// The server stores one global puzzle JSON per day.  This repo fetches it and
/// maps it into the same [DailyPuzzleModel] shape the local repo uses so the
/// rest of the service layer is unaffected.
///
/// Throws on network failure so callers can fall back to SQLite cache.
class RemoteDailyPuzzleRepository {
  // ── Mirror the local repo's public surface ───────────────────────────────

  /// Fetches today's global puzzle from the server and returns a
  /// [DailyPuzzleModel] with the server JSON.
  Future<DailyPuzzleModel?> getByUserAndDate(int userId, String date) async {
    // 1. Fetch the global puzzle
    final puzzleData = await ApiClient.get('/daily/today');
    if (puzzleData['date'] != date) return null; // server returned a different day

    // 2. Fetch per-user progress
    final progressData = await ApiClient.get('/daily/progress');

    final model = DailyPuzzleModel(
      userId:         userId,
      date:           date,
      puzzleJson:     puzzleData['puzzleJson'] as String,   // already JSON-encoded string
      gridJson:       progressData['gridJson'] as String?,
      solved:         (progressData['solved'] as bool? ?? false) ? 1 : 0,
      swapsUsed:      progressData['swapsUsed']      as int? ?? 0,
      hintCount:      progressData['hintCount']      as int? ?? 0,
      totalSwapCount: progressData['totalSwapCount'] as int? ?? 0,
    );
    return model;
  }

  /// Saves grid state to the server.
  Future<void> upsert(
    int userId,
    String date, {
    String? puzzleJson,
    String? gridJson,
    bool?   solved,
    int?    swapsUsed,
    int?    hintCount,
    int?    totalSwapCount,
  }) async {
    if (solved == true) {
      // Marking solved: POST /api/daily/solved
      await ApiClient.postVoid('/daily/solved', body: {
        'swapsUsed':      swapsUsed      ?? 0,
        'hintCount':      hintCount      ?? 0,
        'totalSwapCount': totalSwapCount ?? 0,
      });
    } else if (gridJson != null) {
      // Saving grid progress: POST /api/daily/progress
      await ApiClient.postVoid('/daily/progress', body: {
        'gridJson':       gridJson,
        'swapsUsed':      swapsUsed      ?? 0,
        'hintCount':      hintCount      ?? 0,
        'totalSwapCount': totalSwapCount ?? 0,
      });
    }
  }

  Future<DailyPuzzleModel?> getTodayPuzzle(int userId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return getByUserAndDate(userId, today);
  }
}
