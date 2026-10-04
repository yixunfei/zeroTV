import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/widgets/error_view.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Subscription management page: list all subscriptions with channel
/// counts, toggle auto-sync, rename, delete, or sync one manually.
class SubscriptionsPage extends ConsumerWidget {
  /// Creates the page.
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subsAsync = ref.watch(subscriptionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscriptionsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addSubscription,
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
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(subscriptionsProvider),
        ),
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
          Text(
            AppLocalizations.of(context).noSubscriptions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.pushNamed('add-subscription'),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).addSubscription),
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

  /// Pasted-text imports and manual channels are one-shot: there is no
  /// source to re-fetch.
  bool get _syncable =>
      _sub.kind != SubscriptionKind.pastedText &&
      _sub.kind != SubscriptionKind.manual;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = ref.watch(channelCountsProvider).value ?? const {};
    final count = counts[_sub.id] ?? 0;
    return ListTile(
      title: Text(_sub.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        l10n.subscriptionMeta(
          _kindLabel(l10n, _sub.kind),
          count,
          _syncLabel(l10n, _sub),
        ),
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
            message: _syncable ? l10n.autoSync : l10n.syncUnsupported,
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
                child: Text(l10n.syncNow),
              ),
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
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
    final l10n = AppLocalizations.of(context);
    try {
      final result = await ref.read(syncSubscriptionProvider)(_sub);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.syncDone(result.channelCount),
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.syncFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _rename() async {
    // Resolve dependencies before awaiting the dialog: the tile can be
    // removed from the tree (list update, page pop) while it is open.
    final manager = ref.read(manageSubscriptionProvider);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initialName: _sub.name),
    );
    if (newName == null || newName == _sub.name) return;
    await manager.rename(_sub.id, newName);
  }

  Future<void> _delete() async {
    // Resolve dependencies before awaiting the dialog (see _rename).
    final manager = ref.read(manageSubscriptionProvider);
    final counts = ref.read(channelCountsProvider).value ?? const {};
    final count = counts[_sub.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.deleteSubscription),
          content: Text(l10n.deleteSubscriptionBody(_sub.name, count)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await manager.remove(_sub.id);
    }
  }

  static String _kindLabel(AppLocalizations l10n, SubscriptionKind kind) {
    return switch (kind) {
      SubscriptionKind.remoteUrl => l10n.kindRemote,
      SubscriptionKind.localFile => l10n.kindFile,
      SubscriptionKind.pastedText => l10n.kindPasted,
      SubscriptionKind.manual => l10n.kindManual,
    };
  }

  static String _syncLabel(AppLocalizations l10n, Subscription sub) {
    final synced = sub.lastSyncedAt;
    if (synced == null) return l10n.neverSynced;
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.renameSubscription),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.subscriptionName),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }
}
