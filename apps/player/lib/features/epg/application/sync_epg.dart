import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/epg/application/epg_settings.dart';

/// Use case: fetch the configured EPG feed and replace stored EPG data.
///
/// A no-op when no EPG URL is configured. On fetch/parse failure the
/// previously stored EPG data is left untouched (the replace happens
/// only after a successful parse, which then also stamps the last-sync
/// time used by automatic refresh).
class SyncEpg {
  /// Creates the use case.
  SyncEpg({
    required EpgProvider provider,
    required EpgRepository repository,
    required EpgSettings settings,
    DateTime Function() now = DateTime.now,
  }) : _provider = provider,
       _repository = repository,
       _settings = settings,
       _now = now;

  final EpgProvider _provider;
  final EpgRepository _repository;
  final EpgSettings _settings;
  final DateTime Function() _now;

  /// Syncs the configured feed; returns the parsed feed, or null when
  /// no URL is configured.
  Future<EpgFeed?> call() async {
    final uri = _settings.url;
    if (uri == null) return null;
    final feed = await _provider.fetch(uri);
    await _repository.replaceFeed(feed);
    await _settings.setLastSynced(_now());
    return feed;
  }
}
