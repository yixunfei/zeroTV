/// Built-in default subscription, seeded on first launch.
///
/// Points at the community-maintained vbskycn/iptv list (updated every 6h).
/// The app stores no channel content itself; this is only a pointer that
/// users can delete or replace like any other subscription.
abstract final class DefaultSubscription {
  /// Display name of the seeded subscription.
  static const name = '默认源 · vbskycn/iptv';

  /// Candidate playlist URLs, tried in order. The first is the project's
  /// own CDN; the others are GitHub mirrors for unreliable networks.
  static const candidates = [
    'https://live.zbds.top/tv/iptv4.m3u',
    'https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u',
    'https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u',
  ];

  /// Whether [uri] belongs to the default candidate set (then all
  /// candidates are eligible as mirror fallback).
  static bool isDefaultUri(String? uri) => candidates.contains(uri);
}
