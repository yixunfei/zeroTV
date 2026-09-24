import 'package:iptv_core/iptv_core.dart';

/// The programme currently airing plus the next one, for one channel.
class NowNext {
  /// Creates the pair.
  const NowNext({this.now, this.next});

  /// Programme airing now, if any.
  final EpgProgram? now;

  /// Following programme, if any.
  final EpgProgram? next;
}

/// Resolves "now / next" programmes for a channel within a guide window.
class EpgGuide {
  /// Creates the guide over a [from]-[to] window.
  const EpgGuide({required this.from, required this.to});

  /// Window start (typically now).
  final DateTime from;

  /// Window end (typically now + a few hours).
  final DateTime to;

  /// Computes now/next for [programmes] (sorted by start, already in
  /// window). `now` is the programme whose `[start, stop)` range contains
  /// [from] or the first upcoming one; `next` follows it.
  NowNext resolve(List<EpgProgram> programmes) {
    EpgProgram? now;
    EpgProgram? next;
    for (final p in programmes) {
      if (p.stop.isAfter(from) && !p.start.isAfter(from)) {
        now = p;
      } else if (p.start.isAfter(from) && next == null) {
        next = p;
      }
    }
    return NowNext(now: now, next: next);
  }
}
