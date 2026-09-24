import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/channel_filter.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// Home page: grouped channel list, gated on first-run bootstrap
/// (default-source seeding + initial sync).
class ChannelListPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ChannelListPage({super.key});

  @override
  ConsumerState<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends ConsumerState<ChannelListPage> {
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() => _searching = true);
    ref.read(channelFilterProvider.notifier).current = const FilterSearch('');
  }

  void _exitSearch() {
    _searchController.clear();
    setState(() => _searching = false);
    ref.read(channelFilterProvider.notifier).current = const FilterAll();
  }

  void _onQueryChanged(String query) {
    ref.read(channelFilterProvider.notifier).current = FilterSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bootstrapProvider, (_, next) {
      final failures = next.value;
      if (failures != null && failures.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${failures.length} 个订阅同步失败，已保留旧数据')),
        );
      }
    });
    final bootstrap = ref.watch(bootstrapProvider);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索频道…',
                  border: InputBorder.none,
                ),
                onChanged: _onQueryChanged,
              )
            : const Text('zeroTV'),
        actions: [
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '退出搜索',
              onPressed: _exitSearch,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: _enterSearch,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '设置',
              onPressed: () => context.goNamed('settings'),
            ),
          ],
        ],
      ),
      body: switch (bootstrap) {
        AsyncLoading() => const _BootHint('正在同步订阅源…'),
        AsyncError(:final error) => _BootError(error: error),
        AsyncData() => const _ChannelBrowser(),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('add-subscription'),
        icon: const Icon(Icons.add),
        label: const Text('添加订阅'),
      ),
    );
  }
}

class _BootHint extends StatelessWidget {
  const _BootHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _BootError extends ConsumerWidget {
  const _BootError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text('订阅源同步失败', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => ref.invalidate(bootstrapProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _ChannelBrowser extends ConsumerWidget {
  const _ChannelBrowser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(allGroupsProvider).value ?? const <String>[];
    final filter = ref.watch(channelFilterProvider);
    final channelsAsync = ref.watch(filteredChannelsProvider);
    return Column(
      children: [
        if (filter is! FilterSearch)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: '全部',
                  selected: filter is FilterAll,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterAll(),
                ),
                _FilterChip(
                  label: '收藏',
                  selected: filter is FilterFavorites,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterFavorites(),
                ),
                _FilterChip(
                  label: '最近',
                  selected: filter is FilterRecent,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterRecent(),
                ),
                for (final g in groups)
                  _FilterChip(
                    label: g,
                    selected: filter is FilterGroup && filter.group == g,
                    onSelected: () =>
                        ref.read(channelFilterProvider.notifier).current =
                            FilterGroup(g),
                  ),
              ],
            ),
          ),
        if (filter is! FilterSearch) const Divider(height: 1),
        Expanded(
          child: switch (channelsAsync) {
            AsyncData(:final value) when value.isEmpty => _EmptyHint(
              filter: filter,
            ),
            AsyncData(:final value) => _ChannelList(channels: value),
            AsyncError(:final error) => Center(child: Text('加载失败：$error')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({required this.channels});

  final List<Channel> channels;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, i) => _ChannelTile(channel: channels[i]),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = channel.logoUrl;
    final favorites = ref.watch(favoriteKeysProvider).value ?? const <String>{};
    final isFavorite = favorites.contains(channel.identityKey);
    return ListTile(
      leading: logo == null
          ? const Icon(Icons.live_tv_outlined, size: 32)
          : Image.network(
              logo,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.live_tv_outlined, size: 32),
            ),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(channel.groupTitle ?? ungroupedGroupLabel),
      trailing: IconButton(
        icon: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          color: isFavorite ? Colors.amber : null,
        ),
        tooltip: isFavorite ? '取消收藏' : '收藏',
        onPressed: () => unawaited(ref.read(toggleFavoriteProvider)(channel)),
      ),
      onTap: () => context.pushNamed('player', extra: channel),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.filter});

  final ChannelFilter filter;

  @override
  Widget build(BuildContext context) {
    final (title, hint) = switch (filter) {
      FilterFavorites() => ('还没有收藏频道', '点频道右侧的星标即可收藏'),
      FilterRecent() => ('还没有观看记录', '播放过的频道会出现在这里'),
      FilterSearch(:final query) => ('没有找到「$query」', '换个关键字试试'),
      _ => ('还没有任何频道', '添加订阅源后即可开始观看'),
    };
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.live_tv_outlined,
            size: 72,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
