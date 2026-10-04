import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/epg/application/epg_guide.dart';

/// Resolves now/next programmes for app channels from EPG data.
///
/// Matching is by `tvgId` first, falling back to a case-insensitive,
/// whitespace-normalized display-name match (the same degraded strategy
/// used across the app for channels that lack a `tvg-id`).
class EpgIndex {
  /// Creates an index.
  EpgIndex({
    required this.byEpgId,
    required this.byNormalizedName,
    this.knownEpgIds = const {},
  });

  /// Now/next keyed by XMLTV channel id.
  final Map<String, NowNext> byEpgId;

  /// XMLTV channel id keyed by normalized display name.
  final Map<String, String> byNormalizedName;

  /// Every XMLTV channel id listed in the feed, including channels
  /// without programmes in the now/next window.
  final Set<String> knownEpgIds;

  /// Whether any EPG data is available.
  bool get isEmpty =>
      byEpgId.isEmpty && byNormalizedName.isEmpty && knownEpgIds.isEmpty;

  /// Now/next for [channel], or null when nothing matches.
  NowNext? forChannel(Channel channel) {
    final epgId = epgIdFor(channel);
    if (epgId == null) return null;
    return byEpgId[epgId];
  }

  /// The XMLTV channel id matching [channel], by `tvgId` first and
  /// falling back to a normalized display-name match. Null when the
  /// feed does not cover the channel at all.
  String? epgIdFor(Channel channel) {
    final tvgId = channel.tvgId?.trim();
    if (tvgId != null &&
        tvgId.isNotEmpty &&
        (knownEpgIds.contains(tvgId) || byEpgId.containsKey(tvgId))) {
      return tvgId;
    }
    return byNormalizedName[normalize(channel.name)];
  }

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Normalizes a channel name for fuzzy EPG matching.
  static String normalize(String name) =>
      name.trim().toLowerCase().replaceAll(_whitespace, '');

  /// An empty index.
  static final empty = EpgIndex(byEpgId: const {}, byNormalizedName: const {});
}
