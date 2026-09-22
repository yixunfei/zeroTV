import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Home page: grouped channel list. M0 shell with an empty state;
/// the real list lands in M1.
class ChannelListPage extends StatelessWidget {
  /// Creates the page.
  const ChannelListPage({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: const _EmptyState(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // M1: add-subscription sheet (URL / file / pasted text).
        },
        icon: const Icon(Icons.add),
        label: const Text('添加订阅'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
