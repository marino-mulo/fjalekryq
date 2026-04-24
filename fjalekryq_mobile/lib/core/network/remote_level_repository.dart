import 'dart:convert';

import '../models/puzzle.dart';
import 'api_client.dart';

/// Result of fetching a numbered level from the server.
class RemoteLevel {
  final int level;
  final String difficulty;
  final Wordle7Puzzle puzzle;

  const RemoteLevel({
    required this.level,
    required this.difficulty,
    required this.puzzle,
  });
}

/// Fetches numbered-level puzzles from the server.
///
/// The server is the source of truth for level puzzles: any `n >= 1` is
/// valid; the first request for a level triggers server-side generation
/// (< 1s), subsequent requests are instant.
class RemoteLevelRepository {
  Future<RemoteLevel> getLevel(int level) async {
    final data = await ApiClient.get('/levels/$level');
    // `puzzleJson` is a JSON-encoded string — decode it once more to get
    // the actual puzzle object (same contract as the daily puzzle).
    final puzzle = Wordle7Puzzle.fromJson(
      jsonDecode(data['puzzleJson'] as String) as Map<String, dynamic>,
    );
    return RemoteLevel(
      level:      data['level']      as int,
      difficulty: data['difficulty'] as String,
      puzzle:     puzzle,
    );
  }
}
