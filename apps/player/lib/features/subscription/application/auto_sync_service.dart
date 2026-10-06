import 'dart:async';
import 'dart:math' as math;

import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/application/sync_subscription.dart';

/// A single subscription that failed during an auto-sync pass.
class SyncFailure {
  /// Creates the failure record.
  const SyncFailure(this.subscriptionId, this.error);

  /// The failed subscription.
  final String subscriptionId;

  /// Diagnostic message.
  final String error;
}

/// Syncs enabled subscriptions whose refresh interval has elapsed.
///
/// Passes run with bounded parallelism and a hard per-subscription
/// timeout so a single unreachable source can never stall the others.
/// Individual failures are collected and returned, never thrown, and
/// never destroy previously synced data.
class AutoSyncService {
  /// Creates the service.
  AutoSyncService({
    required SubscriptionRepository subscriptions,
    required SyncSubscription sync,
  }) : _subscriptions = subscriptions,
       _sync = sync;

  /// How many subscriptions sync in parallel.
  static const _concurrency = 3;

  /// Hard cap for one subscription's fetch+parse+store. Slow sources
  /// are reported as failures instead of stalling the whole pass; if
  /// the request eventually completes its data is still stored.
  static const _perSubscriptionTimeout = Duration(seconds: 45);

  final SubscriptionRepository _subscriptions;
  final SyncSubscription _sync;

  /// In-flight pass shared by concurrent callers (bootstrap, scheduler,
  /// pull-to-refresh) so syncs never run twice at the same time. Null
  /// when no pass is running; [_ongoingAll] records whether it covers
  /// every subscription or only the due ones.
  Future<List<SyncFailure>>? _ongoing;
  bool _ongoingAll = false;

  /// Syncs all due subscriptions; returns the failures (empty on success).
  ///
  /// When [intervalOverride] is provided, it replaces each subscription's
  /// own refresh interval for the due check (used by the user's global
  /// "sync interval" setting).
  Future<List<SyncFailure>> syncDue({
    Duration? intervalOverride,
    void Function(int completed, int total)? onProgress,
  }) {
    return _dedup(
      all: false,
      run: () => _run(
        onlyDue: true,
        intervalOverride: intervalOverride,
        onProgress: onProgress,
      ),
    );
  }

  /// Syncs every syncable subscription regardless of schedule and of
  /// the per-subscription auto-sync toggle (which only gates automatic
  /// runs). Backs the user's manual "refresh all" action. Returns the
  /// failures (empty on success).
  Future<List<SyncFailure>> syncAll({
    void Function(int completed, int total)? onProgress,
  }) {
    return _dedup(
      all: true,
      run: () => _run(onlyDue: false, onProgress: onProgress),
    );
  }

  Future<List<SyncFailure>> _dedup({
    required bool all,
    required Future<List<SyncFailure>> Function() run,
  }) async {
    while (true) {
      final ongoing = _ongoing;
      if (ongoing != null) {
        // Reuse the in-flight pass — unless a full pass is requested
        // while a due-only pass is running: reusing it would report
        // success without syncing the not-yet-due subscriptions.
        if (!all || _ongoingAll) return ongoing;
        try {
          await ongoing;
        } on Object {
          // The due-only pass failed outright; still run our full pass.
        }
        continue;
      }
      final future = run();
      _ongoing = future;
      _ongoingAll = all;
      try {
        return await future;
      } finally {
        if (identical(_ongoing, future)) {
          _ongoing = null;
          _ongoingAll = false;
        }
      }
    }
  }

  Future<List<SyncFailure>> _run({
    required bool onlyDue,
    Duration? intervalOverride,
    void Function(int completed, int total)? onProgress,
  }) async {
    final subs = await _subscriptions.getAll();
    final targets = [
      for (final s in subs)
        if (_isSyncable(
          s,
          onlyDue: onlyDue,
          intervalOverride: intervalOverride,
        ))
          s,
    ];
    final failures = <SyncFailure>[];
    var completed = 0;
    onProgress?.call(0, targets.length);
    var next = 0;
    Future<void> worker() async {
      // Safe without locking: the index read/increment never crosses
      // an await boundary.
      while (next < targets.length) {
        final s = targets[next++];
        try {
          await _sync(s).timeout(_perSubscriptionTimeout);
        } on TimeoutException {
          failures.add(
            SyncFailure(
              s.id,
              'sync timeout >${_perSubscriptionTimeout.inSeconds}s',
            ),
          );
        } on Object catch (e) {
          failures.add(SyncFailure(s.id, '$e'));
        } finally {
          completed++;
          onProgress?.call(completed, targets.length);
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(_concurrency, targets.length); i++) worker(),
    ]);
    return failures;
  }

  bool _isSyncable(
    Subscription s, {
    required bool onlyDue,
    Duration? intervalOverride,
  }) {
    if (s.kind == SubscriptionKind.manual ||
        s.kind == SubscriptionKind.pastedText) {
      return false;
    }
    if (!onlyDue) return true;
    return s.enabled && _isDue(s, intervalOverride);
  }

  bool _isDue(Subscription s, Duration? override) {
    if (override == null) return s.isDue;
    final synced = s.lastSyncedAt;
    if (synced == null) return true;
    return DateTime.now().difference(synced) >= override;
  }
}
