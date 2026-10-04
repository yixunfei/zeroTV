import 'package:iptv_core/iptv_core.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/subscription/application/sync_subscription.dart';
import 'package:zerotv_player/features/subscription/data/sources/pasted_text_source.dart';
import 'package:zerotv_player/features/subscription/domain/default_subscription.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';

/// Use case: add a subscription from a URL, a local file, or pasted text,
/// then perform the initial sync and return its result.
class AddSubscription {
  /// Creates the use case.
  AddSubscription({
    required SubscriptionRepository subscriptions,
    required ChannelRepository channels,
    required PlaylistParser parser,
    required SyncSubscription sync,
  }) : _subscriptions = subscriptions,
       _channels = channels,
       _parser = parser,
       _sync = sync;

  final SubscriptionRepository _subscriptions;
  final ChannelRepository _channels;
  final PlaylistParser _parser;
  final SyncSubscription _sync;

  /// Adds a remote M3U URL subscription and syncs it.
  ///
  /// When [url] matches a curated built-in source, the source's display
  /// name and channel-group prefix are applied automatically. When a
  /// subscription with the same URL — or another mirror of the same
  /// built-in source — already exists, it is re-synced instead of
  /// duplicated (a new [name] is applied if given).
  Future<SyncResult> fromUrl({required Uri url, String? name}) async {
    final urlStr = '$url';
    final builtin = DefaultSubscription.sourceFor(urlStr);
    final existing = await _subscriptions.getAll();
    for (final candidate in existing) {
      final duplicate =
          candidate.uri == urlStr ||
          (builtin != null && builtin.owns(candidate.uri));
      if (duplicate) {
        final renamed = _withName(candidate, name);
        return renamed == null ? _sync(candidate) : _upsertAndSync(renamed);
      }
    }
    final sub = Subscription(
      id: const Uuid().v4(),
      name: (name == null || name.trim().isEmpty)
          ? (builtin?.name ?? url.host)
          : name.trim(),
      kind: SubscriptionKind.remoteUrl,
      uri: urlStr,
      channelGroupPrefix: builtin?.channelGroupPrefix,
    );
    return _addAndSync(sub);
  }

  /// Adds a local playlist file subscription and syncs it.
  Future<SyncResult> fromFile({required String path, String? name}) {
    final sub = Subscription(
      id: const Uuid().v4(),
      name: (name == null || name.trim().isEmpty)
          ? p.basenameWithoutExtension(path)
          : name.trim(),
      kind: SubscriptionKind.localFile,
      uri: path,
    );
    return _addAndSync(sub);
  }

  /// Imports pasted playlist text as a one-shot subscription (no re-sync;
  /// the text itself is not persisted).
  Future<SyncResult> fromText({
    required String name,
    required String content,
  }) async {
    final sub = Subscription(
      id: const Uuid().v4(),
      name: name.trim(),
      kind: SubscriptionKind.pastedText,
      enabled: false,
    );
    final parsed = _parser.parse(await PastedTextSource(content).fetch());
    // Filter exactly like a regular sync so pasted imports don't smuggle
    // in the ad/promotion channels SyncSubscription would drop.
    final cleaned = _sync.cleanChannels(sub, parsed.channels);
    if (cleaned.isEmpty) {
      throw const SubscriptionFetchException('未找到有效频道');
    }
    await _subscriptions.upsert(sub);
    try {
      await _channels.replaceAll(sub.id, cleaned);
      await _subscriptions.markSynced(sub.id, DateTime.now());
    } on Object {
      // Don't leave an empty subscription row behind when persisting
      // the parsed channels fails.
      await _subscriptions.remove(sub.id);
      rethrow;
    }
    return SyncResult(
      subscriptionId: sub.id,
      channelCount: cleaned.length,
      epgUrl: parsed.epgUrl,
    );
  }

  Future<SyncResult> _upsertAndSync(Subscription sub) async {
    await _subscriptions.upsert(sub);
    return _sync(sub);
  }

  /// Upserts a newly created [sub] and syncs it. When the initial sync
  /// fails the row is removed again so no empty subscription is left
  /// behind (mirrors [fromText]).
  Future<SyncResult> _addAndSync(Subscription sub) async {
    await _subscriptions.upsert(sub);
    try {
      return await _sync(sub);
    } on Object {
      await _subscriptions.remove(sub.id);
      rethrow;
    }
  }

  /// Returns a copy of [sub] with [name] applied, or null when [name] is
  /// null/blank or already the subscription's name.
  Subscription? _withName(Subscription sub, String? name) {
    if (name == null || name.trim().isEmpty || name.trim() == sub.name) {
      return null;
    }
    return Subscription(
      id: sub.id,
      name: name.trim(),
      kind: sub.kind,
      uri: sub.uri,
      refreshInterval: sub.refreshInterval,
      enabled: sub.enabled,
      lastSyncedAt: sub.lastSyncedAt,
      channelGroupPrefix: sub.channelGroupPrefix,
    );
  }
}
