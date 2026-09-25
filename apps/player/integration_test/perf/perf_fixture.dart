/// Performance fixture: builds large in-memory channel datasets so the
/// perf tests can exercise real provider/list code paths without
/// touching drift or the network.
library;

import 'package:iptv_core/iptv_core.dart';

/// Builds [count] deterministic channels spread across [groupCount]
/// groups. Names are padded so identity keys stay unique and the
/// list is not accidentally collapsed by dedup logic.
List<Channel> buildPerfChannels({int count = 5000, int groupCount = 20}) {
  final groups = List<String>.generate(
    groupCount,
    (i) => 'Perf Group ${i.toString().padLeft(2, '0')}',
  );
  return List<Channel>.generate(count, (i) {
    return Channel(
      name: 'Perf Channel ${i.toString().padLeft(5, '0')}',
      streamUrl: 'http://perf.local/stream/$i',
      tvgId: 'perf-$i',
      groupTitle: groups[i % groupCount],
    );
  });
}

/// Distinct sorted group titles derived from [channels].
List<String> perfGroupsOf(List<Channel> channels) {
  final set = <String>{};
  for (final c in channels) {
    final g = c.groupTitle;
    if (g != null) set.add(g);
  }
  final list = set.toList()..sort();
  return list;
}
