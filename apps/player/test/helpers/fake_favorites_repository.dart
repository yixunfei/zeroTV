import 'dart:async';

import 'package:iptv_core/iptv_core.dart';

/// In-memory [FavoritesRepository] for widget and use-case tests:
/// reactive (mutations re-emit), no drift, no pending timers.
class FakeFavoritesRepository implements FavoritesRepository {
  /// Creates the fake with optional initial keys.
  FakeFavoritesRepository([Set<String>? initial]) : _keys = {...?initial};

  final Set<String> _keys;
  final _changes = StreamController<Set<String>>.broadcast();

  @override
  Stream<Set<String>> watchKeys() async* {
    yield Set.unmodifiable(_keys);
    yield* _changes.stream;
  }

  @override
  Future<bool> isFavorite(String channelKey) async {
    return _keys.contains(channelKey);
  }

  @override
  Future<void> add(String channelKey) async {
    _keys.add(channelKey);
    _notify();
  }

  @override
  Future<void> remove(String channelKey) async {
    _keys.remove(channelKey);
    _notify();
  }

  void _notify() => _changes.add(Set.unmodifiable(_keys));
}
