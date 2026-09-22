import 'dart:async';

import 'package:iptv_core/iptv_core.dart';

/// In-memory [SubscriptionRepository] for widget and use-case tests:
/// reactive (mutations re-emit), no drift, no pending timers.
class FakeSubscriptionRepository implements SubscriptionRepository {
  /// Creates the fake with optional initial data.
  FakeSubscriptionRepository([List<Subscription>? initial])
    : _subscriptions = [...?initial];

  final List<Subscription> _subscriptions;
  final _changes = StreamController<List<Subscription>>.broadcast();

  @override
  Stream<List<Subscription>> watchAll() async* {
    yield List.unmodifiable(_subscriptions);
    yield* _changes.stream;
  }

  @override
  Future<List<Subscription>> getAll() async {
    return List.unmodifiable(_subscriptions);
  }

  @override
  Future<void> upsert(Subscription subscription) async {
    final i = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (i >= 0) {
      _subscriptions[i] = subscription;
    } else {
      _subscriptions.add(subscription);
    }
    _notify();
  }

  @override
  Future<void> remove(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    _notify();
  }

  @override
  Future<void> markSynced(String id, DateTime syncedAt) async {
    _replace(id, lastSyncedAt: syncedAt);
  }

  @override
  Future<void> rename(String id, String name) async {
    _replace(id, name: name);
  }

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {
    _replace(id, enabled: enabled);
  }

  void _replace(
    String id, {
    String? name,
    bool? enabled,
    DateTime? lastSyncedAt,
  }) {
    final i = _subscriptions.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final s = _subscriptions[i];
    _subscriptions[i] = Subscription(
      id: s.id,
      name: name ?? s.name,
      kind: s.kind,
      uri: s.uri,
      refreshInterval: s.refreshInterval,
      enabled: enabled ?? s.enabled,
      lastSyncedAt: lastSyncedAt ?? s.lastSyncedAt,
    );
    _notify();
  }

  void _notify() => _changes.add(List.unmodifiable(_subscriptions));
}
