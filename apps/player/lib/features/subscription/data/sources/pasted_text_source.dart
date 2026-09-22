import 'package:iptv_core/iptv_core.dart';

/// Wraps playlist text pasted by the user (one-shot, not re-syncable).
class PastedTextSource implements SubscriptionSource {
  /// Creates the source.
  const PastedTextSource(this.content);

  /// The pasted playlist text.
  final String content;

  @override
  Future<RawPlaylist> fetch() async => RawPlaylist(content: content);
}
