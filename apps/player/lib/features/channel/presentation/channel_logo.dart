import 'package:flutter/material.dart';

/// Channel logo with in-memory caching, a quiet placeholder while
/// loading and a generic fallback on error or missing URL.
///
/// Uses the framework's `Image.network` (memory-cached via `ImageCache`)
/// instead of a disk-cache package: logos are small and the disk-cache
/// dependency chain (cache manager + its SQL store) measurably inflates
/// the app bundle for little benefit here.
///
/// [headers] passes the channel's anti-hotlinking `User-Agent`/`Referer`
/// (see `Channel.httpHeaders`); some sources reject bare logo requests
/// with 403, which would otherwise show the fallback icon forever.
class ChannelLogo extends StatelessWidget {
  /// Creates the widget.
  const ChannelLogo({
    required this.logoUrl,
    this.size = 40,
    this.headers = const {},
    super.key,
  });

  /// Remote logo URL; null falls back to the placeholder icon.
  final String? logoUrl;

  /// Square edge length.
  final double size;

  /// HTTP headers sent with the logo request.
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return _fallback();
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * 3).round(),
      headers: headers,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) return child;
        return _fallback();
      },
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Icon(Icons.live_tv_outlined, size: size * 0.8);
  }
}
