/// A built-in curated source, seeded on first launch.
///
/// The app stores no channel content itself; these are only pointers to
/// community-maintained public playlists that users can delete or replace
/// like any other subscription.
class BuiltinSource {
  /// Creates the source descriptor.
  const BuiltinSource({
    required this.name,
    required this.candidates,
    required this.sinceVersion,
    this.channelGroupPrefix,
    this.filterAds = true,
  });

  /// Display name of the seeded subscription.
  final String name;

  /// Candidate playlist URLs, tried in order (mirror fallback).
  final List<String> candidates;

  /// Catalog version this source first appeared in. The seeder only
  /// adds sources introduced after the version the device last seeded,
  /// so catalogue additions reach existing installs without
  /// resurrecting sources the user deleted.
  final int sinceVersion;

  /// When set, every channel group of this source is renamed to
  /// `"$channelGroupPrefix · <original group>"`, giving each built-in
  /// source its own section in the group switcher.
  final String? channelGroupPrefix;

  /// Whether the ad/promotion keyword filter runs on this source's
  /// entries at sync time. Curated Chinese sources opt in; global
  /// catalogues (iptv-org) keep upstream entries untouched.
  final bool filterAds;

  /// Whether [uri] belongs to this source's candidate set (then all
  /// candidates are eligible as mirror fallback).
  bool owns(String? uri) => candidates.contains(uri);
}

/// Curated ad-free built-in sources seeded on first launch.
///
/// Sources carrying promotional/advertising channels ("更新时间", "支持作者",
/// donation/QR-code entries, …) are intentionally excluded. As an extra
/// safety net, sources with [BuiltinSource.filterAds] enabled filter such
/// entries at sync time.
abstract final class DefaultSubscription {
  /// Current catalog version; bumped whenever [sources] grows so the
  /// seeder picks the additions up on existing installs.
  static const catalogVersion = 3;

  /// Curated built-in sources, in seeding order.
  static const sources = <BuiltinSource>[
    BuiltinSource(
      name: '默认源 · vbskycn/iptv',
      channelGroupPrefix: '综合',
      sinceVersion: 1,
      candidates: [
        'https://live.zbds.top/tv/iptv4.m3u',
        'https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u',
        'https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u',
      ],
    ),
    BuiltinSource(
      name: 'iptv-org · 全球频道',
      channelGroupPrefix: '国际',
      sinceVersion: 2,
      filterAds: false,
      candidates: [
        'https://iptv-org.github.io/iptv/index.m3u',
        'https://cdn.jsdelivr.net/gh/iptv-org/iptv@gh-pages/index.m3u',
      ],
    ),
    BuiltinSource(
      name: 'iptv-org · 中文频道',
      channelGroupPrefix: '国际',
      sinceVersion: 2,
      filterAds: false,
      candidates: [
        'https://iptv-org.github.io/iptv/languages/zho.m3u',
        'https://cdn.jsdelivr.net/gh/iptv-org/iptv@gh-pages/languages/zho.m3u',
      ],
    ),
    BuiltinSource(
      name: 'iptv-org · 新闻频道',
      channelGroupPrefix: '国际',
      sinceVersion: 2,
      filterAds: false,
      candidates: [
        'https://iptv-org.github.io/iptv/categories/news.m3u',
        'https://cdn.jsdelivr.net/gh/iptv-org/iptv@gh-pages/categories/news.m3u',
      ],
    ),
  ];

  /// The first source, kept for backwards compatibility with code that
  /// pre-dates the multi-source catalogue.
  static BuiltinSource get primary => sources.first;

  /// Display name of the first seeded subscription.
  static const name = '默认源 · vbskycn/iptv';

  /// Candidate URLs of the first source (mirror fallback order).
  static List<String> get candidates => primary.candidates;

  /// Looks up the built-in source that [uri] belongs to, or null when
  /// [uri] is not a built-in candidate.
  static BuiltinSource? sourceFor(String? uri) {
    for (final source in sources) {
      if (source.owns(uri)) return source;
    }
    return null;
  }

  /// Whether [uri] belongs to any built-in candidate set (then all of
  /// that set's candidates are eligible as mirror fallback).
  static bool isDefaultUri(String? uri) => sourceFor(uri) != null;

  /// Candidates retired after the source precheck found them unavailable.
  /// Existing installs remove only subscriptions pointing at these exact
  /// built-in URLs; user-owned sources are never matched by name.
  static const retiredUris = <String>{
    'https://mirror.ghproxy.com/https://raw.githubusercontent.com/Ftindy/IPTV-URL/main/SXYD.m3u',
    'https://raw.githubusercontent.com/Ftindy/IPTV-URL/main/SXYD.m3u',
    'https://mirror.ghproxy.com/https://raw.githubusercontent.com/Ftindy/IPTV-URL/main/bestv.m3u',
    'https://raw.githubusercontent.com/Ftindy/IPTV-URL/main/bestv.m3u',
    'https://mirror.ghproxy.com/https://raw.githubusercontent.com/Ftindy/IPTV-URL/main/IPTV.m3u',
    'https://raw.githubusercontent.com/Ftindy/IPTV-URL/main/IPTV.m3u',
  };

  /// Group/channel-name fragments that mark a playlist entry as
  /// promotion/advertisement rather than real content. Such entries are
  /// filtered out at sync time for sources with ad filtering enabled.
  static const adKeywords = [
    '更新时间',
    '支持作者',
    '关注公众号',
    '扫码关注',
    '打赏',
    '赞助',
    '捐赠',
    '公众号',
    '微信群',
    'qq群',
    '客服',
    '广告',
    '招商',
    '加盟',
    '推广',
    '宣传',
    '入口',
    '官网',
    '下载app',
    '添加微信',
    '加微信',
    '微信号',
    '福利',
    '免费分享',
    '每日更新',
    '长期更新',
    '永久更新',
    '仅供交流',
    '免责声明',
    'www.',
    'http://t.cn',
    't.me/',
  ];

  /// Returns true when [name] looks like a promotion/ad entry.
  static bool isAdChannel(String name) {
    final lowered = name.toLowerCase();
    return adKeywords.any(lowered.contains);
  }
}
