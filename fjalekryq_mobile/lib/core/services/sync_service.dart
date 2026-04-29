import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/repositories/progress_repository.dart';
import '../network/api_client.dart';
import '../network/remote_progress_repository.dart';
import 'connectivity_service.dart';

/// Pushes any local-only state to the server when the device comes online.
///
/// Scoped to level completions: HybridProgressRepository writes locally first
/// and best-effort pushes to the server. When offline the row stays in SQLite;
/// this service replays those completions via POST /api/progress/{level}.
class SyncService {
  final int _userId;
  final ProgressRepository _progressRepo;
  final RemoteProgressRepository _remoteProgress;
  final ConnectivityService _connectivity;

  bool _running = false;
  bool _wasOnline;
  VoidCallback? _connectivityListener;

  SyncService({
    required int userId,
    required ProgressRepository progressRepo,
    required RemoteProgressRepository remoteProgress,
    required ConnectivityService connectivity,
  })  : _userId = userId,
        _progressRepo = progressRepo,
        _remoteProgress = remoteProgress,
        _connectivity = connectivity,
        _wasOnline = connectivity.isOnline;

  void start() {
    _connectivityListener ??= () {
      final nowOnline = _connectivity.isOnline;
      if (!_wasOnline && nowOnline) unawaited(syncAll());
      _wasOnline = nowOnline;
    };
    _connectivity.addListener(_connectivityListener!);
  }

  void dispose() {
    if (_connectivityListener != null) {
      _connectivity.removeListener(_connectivityListener!);
      _connectivityListener = null;
    }
  }

  Future<void> syncAll() async {
    if (_running) return;
    if (!_connectivity.isOnline) return;
    _running = true;
    try {
      await _syncProgress();
    } finally {
      _running = false;
    }
  }

  Future<void> _syncProgress() async {
    final List<int> remoteLevels;
    try {
      final data = await ApiClient.get('/progress');
      final levels = (data['levels'] as List<dynamic>? ?? []);
      remoteLevels = levels
          .cast<Map<String, dynamic>>()
          .where((l) => l['completed'] == true)
          .map((l) => l['level'] as int)
          .toList();
    } catch (e) {
      debugPrint('SyncService: /progress fetch failed: $e');
      return;
    }

    final remoteSet = remoteLevels.toSet();
    final localCompletions = await _progressRepo.getLocalCompletions(_userId);

    for (final row in localCompletions) {
      if (remoteSet.contains(row.level)) continue;
      try {
        await _remoteProgress.upsert(
          _userId,
          row.level,
          completed: true,
          movesLeft: row.movesLeft ?? 0,
        );
      } catch (e) {
        debugPrint('SyncService: progress push failed for level ${row.level}: $e');
        return;
      }
    }
  }
}
