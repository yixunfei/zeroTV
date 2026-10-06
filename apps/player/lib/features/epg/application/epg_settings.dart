import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user-configured EPG feed URL.
class EpgSettings {
  /// Creates the settings store.
  const EpgSettings(this._prefs);

  /// Shared-preferences key holding the EPG URL.
  static const urlKey = 'epg_url';

  /// Shared-preferences key holding the last successful sync time
  /// (epoch milliseconds).
  static const lastSyncedKey = 'epg_last_synced_at';

  final SharedPreferences _prefs;

  /// The configured EPG URL, or null when unset/blank.
  Uri? get url {
    final raw = _prefs.getString(urlKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return Uri.tryParse(raw.trim());
  }

  /// When the EPG feed was last successfully synced; null when never.
  DateTime? get lastSyncedAt {
    final ms = _prefs.getInt(lastSyncedKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Sets (or clears, when [value] is null/blank) the EPG URL.
  Future<void> setUrl(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _prefs.remove(urlKey);
    } else {
      await _prefs.setString(urlKey, value.trim());
    }
  }

  /// Records a successful sync at [at].
  Future<void> setLastSynced(DateTime at) {
    return _prefs.setInt(lastSyncedKey, at.millisecondsSinceEpoch);
  }
}
