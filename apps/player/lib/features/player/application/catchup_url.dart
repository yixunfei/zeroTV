import 'package:iptv_core/iptv_core.dart';

/// Builds a concrete catchup stream URL from a channel's
/// `catchup-source` template and a programme window.
///
/// Supported placeholders (both `{name}` and `${name}` spellings,
/// following the convention used across IPTV players/tvheadend):
///
/// - `utc`       programme start, ISO 8601 UTC
/// - `utcend`    programme stop, ISO 8601 UTC
/// - `timestamp` / `start`  programme start, Unix epoch seconds
/// - `timestampend` / `stop` programme stop, Unix epoch seconds
/// - `duration`  programme length in seconds
/// - `offset`    seconds from [now] back to the programme start
///
/// Longer tokens are replaced first: `${utc}` is a prefix of
/// `${utcend}`, so a naive order would corrupt the longer placeholder.
String buildCatchupUrl(
  String template,
  EpgProgram programme, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final start = programme.start.toUtc();
  final stop = programme.stop.toUtc();
  final startStamp = '${start.millisecondsSinceEpoch ~/ 1000}';
  final stopStamp = '${stop.millisecondsSinceEpoch ~/ 1000}';
  final duration = '${stop.difference(start).inSeconds.clamp(0, 1 << 62)}';
  final offset = '${reference.difference(start).inSeconds.clamp(0, 1 << 62)}';
  return template
      .replaceAll(r'${timestampend}', stopStamp)
      .replaceAll('{timestampend}', stopStamp)
      .replaceAll(r'${utcend}', stop.toIso8601String())
      .replaceAll('{utcend}', stop.toIso8601String())
      .replaceAll(r'${timestamp}', startStamp)
      .replaceAll('{timestamp}', startStamp)
      .replaceAll(r'${utc}', start.toIso8601String())
      .replaceAll('{utc}', start.toIso8601String())
      .replaceAll(r'${stop}', stopStamp)
      .replaceAll('{stop}', stopStamp)
      .replaceAll(r'${start}', startStamp)
      .replaceAll('{start}', startStamp)
      .replaceAll(r'${duration}', duration)
      .replaceAll('{duration}', duration)
      .replaceAll(r'${offset}', offset)
      .replaceAll('{offset}', offset);
}
