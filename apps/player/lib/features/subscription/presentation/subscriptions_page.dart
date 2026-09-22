import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// Subscription management page: list all subscriptions with channel
/// counts, toggle auto-sync, rename, delete, or sync one manually.
class SubscriptionsPage extends ConsumerWidget {
  /// Creates the page.
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(subscriptionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加订阅',
            onPressed: () => context.pushNamed('add-subscription'),
          ),
        ],
      ),
      body: switch (subsAsync) {
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (context, i) =>
              _SubscriptionTile(subscription: value[i]),
        ),
        AsyncError(:final error) => Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.playlist_remove,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('还没有任何订阅', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.pushNamed('add-subscription'),
            icon: const Icon(Icons.add),
            label: const Text('添加订阅'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends ConsumerStatefulWidget {
  const _SubscriptionTile({required this.subscription});

  final Subscription subscription;

  @override
  ConsumerState<_SubscriptionTile> createState() => _SubscriptionTileState();
}

class _SubscriptionTileState extends ConsumerState<_SubscriptionTile> {
  bool _syncing = false;

  Subscription get _sub => widget.subscription;

  /// Pasted-text imports are one-shot: there is no source to re-fetch.
  bool get _syncable => _sub.kind != SubscriptionKind.pastedText;

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(channelCountsProvider).value ?? const {};
    final count = counts[_sub.id] ?? 0;
    return ListTile(
      title: Text(_sub.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_kindLabel(_sub.kind)} · $count 个频道 · ${_syncLabel(_sub)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_syncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Tooltip(
            message: _syncable ? '自动同步' : '粘贴导入不支持同步',
            child: Switch(
              value: _sub.enabled,
              onChanged: _syncable
                  ? (v) => ref
                        .read(manageSubscriptionProvider)
                        .setEnabled(_sub.id, enabled: v)
                  : null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sync',
                enabled: _syncable,
                child: const Text('立即同步'),
              ),
              const PopupMenuItem(value: 'rename', child: Text('改名')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }

  void _onMenuSelected(String action) {
    switch (action) {
      case 'sync':
        unawaited(_syncNow());
      case 'rename':
        unawaited(_rename());
      case 'delete':
        unawaited(_delete());
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(syncSubscriptionProvider)(_sub);
      messenger.showSnackBar(
        SnackBar(content: Text('同步完成：${result.channelCount} 个频道')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('同步失败：$e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _rename() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initialName: _sub.name),
    );
    if (newName == null || newName == _sub.name) return;
    await ref.read(manageSubscriptionProvider).rename(_sub.id, newName);
  }

  Future<void> _delete() async {
    final counts = ref.read(channelCountsProvider).value ?? const {};
    final count = counts[_sub.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除订阅'),
        content: Text(
          '删除「${_sub.name}」？其 $count 个频道将一并删除；收藏与观看历史保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(manageSubscriptionProvider).remove(_sub.id);
    }
  }

  static String _kindLabel(SubscriptionKind kind) {
    return switch (kind) {
      SubscriptionKind.remoteUrl => '远程 URL',
      SubscriptionKind.localFile => '本地文件',
      SubscriptionKind.pastedText => '粘贴导入',
    };
  }

  static String _syncLabel(Subscription sub) {
    final synced = sub.lastSyncedAt;
    if (synced == null) return '从未同步';
    final t = synced.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('订阅改名'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '订阅名称'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}
