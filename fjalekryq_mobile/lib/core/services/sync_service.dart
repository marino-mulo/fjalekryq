import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/repositories/progress_repository.dart';
import '../network/api_client.dart';
import '../network/remote_coins_repository.dart';
import '../network/remote_progress_repository.dart';
import 'coin_service.dart';
import 'connectivity_service.dart';

/// Pushes any local-only state to the server when the device comes
/// online. Scoped to the two paths where writes can happen while
/// offline:
///
///   1. Level completions: `HybridProgressRepository.upsert` writes
///      locally first and then best-effort pushes to the server. When
///      the push fails (offline), the row stays in SQLite with
///      `completed = 1` and a `moves_left` value. The sync replays
///      those completions through `POST /api/progress/{level}`.
///
///   2. Coin balance: mid-game rewards, ad-watch coins, daily claims
///      and purchases all mutate the local balance directly. The sync
///      pushes the current balance to `POST /api/coins/sync`, and
///      reconciles with whatever the server returns.
///
/// The daily puzzle and streak endpoints already write through the
/// hybrid repos on every action; re-driving them from sync would
/// double-count, so they're intentionally left alone.
class SyncService {
  final int _userId;
  final ProgressRepository _progressRepo;
  final RemoteProgressRepository _remoteProgress;
  final RemoteCoinsRepository _remoteCoins;
  final CoinService _coinService;
  final ConnectivityService _connectivity;

  bool _running = false;
  bool _wasOnline;
  VoidCallback? _connectivityListener;

  SyncService({
    required int userId,
    required ProgressRepository progressRepo,
    required RemoteProgressRepository remoteProgress,
    required RemoteCoinsRepository remoteCoins,
    required CoinService coinService,
    required ConnectivityService connectivity,
  })  : _userId = userId,
        _progressRepo = progressRepo,
        _remoteProgress = remoteProgress,
        _remoteCoins = remoteCoins,
        _coinService = coinService,
        _connectivity = connectivity,
        _wasOnline = connectivity.isOnline;

  /// Subscribe to connectivity changes so sync fires as soon as the
  /// device comes back online.
  void start() {
    _connectivityListener ??= () {
      final nowOnline = _connectivity.isOnline;
      if (!_wasOnline && nowOnline) {
        // Offline → online transition. Fire and forget; errors are
        // logged inside syncAll.
        unawaited(syncAll());
      }
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

  /// Push all pending local state to the server. Safe to call
  /// concurrently — re-entrant calls return immediately while one is
  /// already in flight.
  Future<void> syncAll() async {
    if (_running) return;
    if (!_connectivity.isOnline) return;
    _running = true;
    try {
      await _syncProgress();
      await _syncCoins();
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
      debugPrint('SyncService: /progress fetch failed, skipping progress sync: $e');
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
        // Stop on the first failure — we've probably gone offline
        // again, and spamming further requests won't help.
        debugPrint('SyncService: progress push failed for level ${row.level}: $e');
        return;
      }
    }
  }

  Future<void> _syncCoins() async {
    try {
      final reconciled = await _remoteCoins.syncBalance(_coinService.coins);
      if (reconciled != _coinService.coins) {
        _coinService.setBalance(reconciled);
      }
    } catch (e) {
      debugPrint('SyncService: /coins/sync failed: $e');
    }
  }
}
