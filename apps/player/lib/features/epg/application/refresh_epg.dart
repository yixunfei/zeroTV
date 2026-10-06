import 'package:zerotv_player/features/epg/application/epg_settings.dart';
import 'package:zerotv_player/features/epg/application/sync_epg.dart';

/// How long stored EPG data stays fresh before auto-refresh resyncs.
const epgRefreshInterval = Duration(hours: 12);

/// Use case: refresh the EPG feed when its data has expired.
///
/// Designed to piggyback on the existing subscription auto-sync passes
/// (both the Android WorkManager task and the desktop in-app timer):
/// one call checks the last-sync stamp and only re-fetches when the
/// configured source's data is older than [epgRefreshInterval]. Manual
/// syncs bypass this gate entirely (the user intent is explicit).
///
/// The `onRefreshed` constructor parameter runs after a successful
/// refresh so the caller can invalidate UI caches (the EPG providers
/// are static futures, not drift streams). Its failures are swallowed:
/// the refreshed data is already persisted.
class RefreshEpg {
  /// Creates the use case.
  RefreshEpg({
    required SyncEpg sync,
    required EpgSettings settings,
    Duration interval = epgRefreshInterval,
    DateTime Function() now = DateTime.now,
    void Function()? onRefreshed,
  }) : _sync = sync,
       _settings = settings,
       _interval = interval,
       _now = now,
       _onRefreshed = onRefreshed;

  final SyncEpg _sync;
  final EpgSettings _settings;
  final Duration _interval;
  final DateTime Function() _now;
  final void Function()? _onRefreshed;

  /// Syncs the EPG feed when its data has expired: no-op when no URL
  /// is configured or the last successful sync is younger than the
  /// refresh interval. Returns true when a refresh actually ran.
  /// Never throws.
  Future<bool> call() async {
    if (_settings.url == null) return false;
    final lastSynced = _settings.lastSyncedAt;
    if (lastSynced != null && _now().difference(lastSynced) < _interval) {
      return false;
    }
    try {
      final feed = await _sync();
      if (feed == null) return false;
      // Data persisted; notifying the UI is best-effort from here on.
      try {
        _onRefreshed?.call();
      } on Object {
        // Ignored by design (see constructor doc).
      }
      return true;
    } on Object {
      // A failed refresh keeps the previous stamp: the next pass will
      // retry once the interval has truly elapsed since the last good
      // sync, matching the subscription sync failure semantics.
      return false;
    }
  }
}
