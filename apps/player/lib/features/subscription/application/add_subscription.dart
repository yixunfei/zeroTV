import 'package:iptv_core/iptv_core.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/subscription/application/sync_subscription.dart';
import 'package:zerotv_player/features/subscription/data/sources/pasted_text_source.dart';

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
  Future<SyncResult> fromUrl({required Uri url, String? name}) {
    final sub = Subscription(
      id: const Uuid().v4(),
      name: (name == null || name.trim().isEmpty) ? url.host : name.trim(),
      kind: SubscriptionKind.remoteUrl,
      uri: '$url',
    );
    return _upsertAndSync(sub);
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
    return _upsertAndSync(sub);
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
    await _subscriptions.upsert(sub);
    final parsed = _parser.parse(await PastedTextSource(content).fetch());
    await _channels.replaceAll(sub.id, parsed.channels);
    await _subscriptions.markSynced(sub.id, DateTime.now());
    return SyncResult(
      subscriptionId: sub.id,
      channelCount: parsed.channels.length,
      epgUrl: parsed.epgUrl,
    );
  }

  Future<SyncResult> _upsertAndSync(Subscription sub) async {
    await _subscriptions.upsert(sub);
    return _sync(sub);
  }
}
