import 'dart:io';

import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/text/content_encoding.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';

/// Reads playlist content from a local file (re-read on every sync).
class FileSubscriptionSource implements SubscriptionSource {
  /// Creates the source.
  const FileSubscriptionSource(this.path);

  /// Absolute path of the playlist file.
  final String path;

  @override
  Future<RawPlaylist> fetch() async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const SubscriptionFetchException(
        SyncErrorReason.fileMissing,
        'file not found',
      );
    }
    try {
      return RawPlaylist(
        // Local playlists may be GBK-encoded (no charset marker); decode
        // with BOM/GBK sniffing instead of assuming UTF-8.
        content: decodeTextContent(await file.readAsBytes()),
        originUri: Uri.file(path),
      );
    } on Object catch (e) {
      throw SubscriptionFetchException(
        SyncErrorReason.fileReadFailed,
        'read failed: $e',
      );
    }
  }
}
