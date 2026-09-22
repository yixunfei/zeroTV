import 'dart:io';

import 'package:iptv_core/iptv_core.dart';
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
      throw SubscriptionFetchException('文件不存在：$path');
    }
    try {
      return RawPlaylist(
        content: await file.readAsString(),
        originUri: Uri.file(path),
      );
    } on Object catch (e) {
      throw SubscriptionFetchException('读取文件失败：$e');
    }
  }
}
