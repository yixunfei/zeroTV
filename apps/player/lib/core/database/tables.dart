import 'package:drift/drift.dart';

/// Playlist subscriptions managed by the user.
class Subscriptions extends Table {
  /// Stable unique id (uuid).
  TextColumn get id => text()();

  /// User-facing name.
  TextColumn get name => text()();

  /// Origin kind: remoteUrl / localFile / pastedText.
  TextColumn get kind => text()();

  /// Remote URL or local file path; null for pasted content.
  TextColumn get uri => text().nullable()();

  /// Auto-sync interval in seconds (default 6h).
  IntColumn get refreshIntervalSeconds =>
      integer().withDefault(const Constant(21600))();

  /// Whether auto-sync is enabled.
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// Last successful sync time.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// Creation time.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Channels belonging to a subscription. Replaced wholesale on sync;
/// user data lives in [Favorites]/[WatchHistory], keyed by channel key.
class Channels extends Table {
  /// Surrogate id.
  IntColumn get id => integer().autoIncrement()();

  /// Owning subscription.
  TextColumn get subscriptionId =>
      text().references(Subscriptions, #id, onDelete: KeyAction.cascade)();

  /// Display name.
  TextColumn get name => text()();

  /// Stream endpoint URL.
  TextColumn get streamUrl => text()();

  /// XMLTV channel id for EPG matching.
  TextColumn get tvgId => text().nullable()();

  /// Logo URL.
  TextColumn get logoUrl => text().nullable()();

  /// Group title.
  TextColumn get groupTitle => text().nullable()();

  /// Catchup source template, if any.
  TextColumn get catchupSource => text().nullable()();

  /// Days of catchup the source claims to support.
  IntColumn get catchupDays => integer().nullable()();

  /// HTTP User-Agent required by the source, if any.
  TextColumn get userAgent => text().nullable()();

  /// HTTP Referer required by the source, if any.
  TextColumn get referrer => text().nullable()();

  /// Insertion order within the subscription.
  IntColumn get position => integer()();
}

/// Favorite channels, keyed by [channelKey] (tvgId when present, else
/// normalized name) so they survive sync replacement.
class Favorites extends Table {
  /// Channel identity key.
  TextColumn get channelKey => text()();

  /// When the favorite was added.
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  /// User-defined sort position.
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {channelKey};
}

/// Watch history entries.
class WatchHistory extends Table {
  /// Surrogate id.
  IntColumn get id => integer().autoIncrement()();

  /// Channel identity key (see [Favorites.channelKey]).
  TextColumn get channelKey => text()();

  /// Channel display name snapshot.
  TextColumn get channelName => text()();

  /// When playback started.
  DateTimeColumn get watchedAt => dateTime()();
}

/// Latest stream availability probe per channel, keyed by identity key
/// (see [Favorites.channelKey]) so it survives sync replacement.
class ProbeResults extends Table {
  /// Channel identity key.
  TextColumn get channelKey => text()();

  /// The probed stream URL.
  TextColumn get url => text()();

  /// ProbeStatus name (ok/timeout/dead/unsupported).
  TextColumn get status => text()();

  /// When the probe finished.
  DateTimeColumn get checkedAt => dateTime()();

  /// Round-trip latency in milliseconds, when available.
  IntColumn get latencyMs => integer().nullable()();

  /// HTTP status code, when the endpoint answered over HTTP.
  IntColumn get httpStatus => integer().nullable()();

  /// Diagnostic message for failures.
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {channelKey};
}

/// XMLTV EPG channel metadata, replaced wholesale on each feed sync.
class EpgChannels extends Table {
  /// XMLTV channel id.
  TextColumn get id => text()();

  /// Display name from the feed.
  TextColumn get displayName => text()();

  /// Optional channel icon URL.
  TextColumn get iconUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// XMLTV programme entries, replaced wholesale on each feed sync.
class EpgProgrammes extends Table {
  /// Surrogate id.
  IntColumn get id => integer().autoIncrement()();

  /// Owning XMLTV channel id.
  TextColumn get channelId => text()();

  /// Programme title.
  TextColumn get title => text()();

  /// Start time (UTC).
  DateTimeColumn get start => dateTime()();

  /// End time (UTC).
  DateTimeColumn get stop => dateTime()();

  /// Optional description.
  TextColumn get description => text().nullable()();
}
