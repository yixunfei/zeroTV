/// A single playable TV channel parsed from a playlist.
///
/// Multi-source redundancy (several URLs for one logical channel) is
/// aggregated at the application layer by [tvgId]/name; one [Channel]
/// instance always represents exactly one stream endpoint.
class Channel {
  /// Creates a channel.
  const Channel({
    required this.name,
    required this.streamUrl,
    this.tvgId,
    this.tvgName,
    this.logoUrl,
    this.groupTitle,
    this.catchupSource,
    this.catchupDays,
    this.userAgent,
    this.referrer,
  });

  /// Display name (text after the first unquoted comma in `#EXTINF`;
  /// commas inside the name itself are preserved).
  final String name;

  /// Stream endpoint (HLS/RTSP/UDP/HTTP...).
  final String streamUrl;

  /// XMLTV channel id used to match EPG data.
  final String? tvgId;

  /// Name hint from the source playlist (`tvg-name`).
  final String? tvgName;

  /// Channel logo URL (`tvg-logo`).
  final String? logoUrl;

  /// Group/category title (`group-title`).
  final String? groupTitle;

  /// Catchup/timeshift source template, if the playlist advertises one.
  final String? catchupSource;

  /// How many days of catchup the source claims to support.
  final int? catchupDays;

  /// HTTP User-Agent required by some sources (`#EXTVLCOPT`).
  final String? userAgent;

  /// HTTP Referer required by some sources (`#EXTVLCOPT`).
  final String? referrer;

  /// Identity key used by favorites/history: [tvgId] when present,
  /// otherwise the lower-cased trimmed name.
  String get identityKey {
    final id = tvgId?.trim();
    return id == null || id.isEmpty ? name.trim().toLowerCase() : id;
  }

  /// HTTP headers required to fetch/play this channel, if any.
  Map<String, String> get httpHeaders => {
    'User-Agent': ?userAgent,
    'Referer': ?referrer,
  };
}
