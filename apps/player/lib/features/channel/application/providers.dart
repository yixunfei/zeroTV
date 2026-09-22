import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/features/channel/data/drift_channel_repository.dart';

/// Provides the [ChannelRepository].
final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return DriftChannelRepository(ref.watch(appDatabaseProvider));
});

/// All distinct group titles across subscriptions, sorted.
final allGroupsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(channelRepositoryProvider).watchAllGroups();
});

/// Currently selected group filter; null means "all channels".
final selectedGroupProvider = NotifierProvider<SelectedGroup, String?>(
  SelectedGroup.new,
);

/// Holds the selected group filter.
class SelectedGroup extends Notifier<String?> {
  @override
  String? build() => null;

  /// The current group filter; null shows all channels.
  String? get current => state;

  /// Sets the current group; null clears the filter (show all).
  set current(String? group) => state = group;
}

/// Channels shown in the list, honoring [selectedGroupProvider].
final filteredChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final group = ref.watch(selectedGroupProvider);
  final stream = ref.watch(channelRepositoryProvider).watchAll();
  if (group == null) return stream;
  return stream.map((channels) {
    return [
      for (final c in channels)
        if ((c.groupTitle ?? ungroupedGroupLabel) == group) c,
    ];
  });
});
