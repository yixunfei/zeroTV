import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// Home page: grouped channel list, gated on first-run bootstrap
/// (default-source seeding + initial sync).
class ChannelListPage extends ConsumerWidget {
  /// Creates the page.
  const ChannelListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text('zeroTV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.goNamed('settings'),
          ),
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
    final selected = ref.watch(selectedGroupProvider);
    final channelsAsync = ref.watch(filteredChannelsProvider);
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _GroupChip(
                label: '全部',
                selected: selected == null,
                onSelected: () =>
                    ref.read(selectedGroupProvider.notifier).current = null,
              ),
              for (final g in groups)
                _GroupChip(
                  label: g,
                  selected: selected == g,
                  onSelected: () =>
                      ref.read(selectedGroupProvider.notifier).current = g,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (channelsAsync) {
            AsyncData(:final value) when value.isEmpty => const _EmptyHint(),
            AsyncData(:final value) => _ChannelList(channels: value),
            AsyncError(:final error) => Center(child: Text('加载失败：$error')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
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

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final logo = channel.logoUrl;
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
      onTap: () => context.pushNamed('player', extra: channel),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
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
          Text('还没有任何频道', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '添加订阅源后即可开始观看',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
