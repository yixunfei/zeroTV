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
  });

  /// Now/next keyed by XMLTV channel id.
  final Map<String, NowNext> byEpgId;

  /// XMLTV channel id keyed by normalized display name.
  final Map<String, String> byNormalizedName;

  /// Whether any EPG data is available.
  bool get isEmpty => byEpgId.isEmpty && byNormalizedName.isEmpty;

  /// Now/next for [channel], or null when nothing matches.
  NowNext? forChannel(Channel channel) {
    final tvgId = channel.tvgId;
    if (tvgId != null) {
      final direct = byEpgId[tvgId];
      if (direct != null) return direct;
    }
    final epgId = byNormalizedName[normalize(channel.name)];
    if (epgId == null) return null;
    return byEpgId[epgId];
  }

  /// Normalizes a channel name for fuzzy EPG matching.
  static String normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// An empty index.
  static final empty = EpgIndex(
    byEpgId: const {},
    byNormalizedName: const {},
  );
}
