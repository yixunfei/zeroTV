import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/widgets/error_view.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Watch-history page: every watched channel, latest first, with
/// per-entry removal and a clear-all action. Entries whose channel
/// vanished upstream stay visible (greyed out) so the record is not
/// silently lost.
class HistoryPage extends ConsumerWidget {
  /// Creates the page.
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(recentHistoryProvider);
    // Existence check uses the full channel table (not the alive-only
    // view): a dead-marked channel still exists upstream, and while the
    // table is still loading nothing should be flagged as gone.
    final channels = ref.watch(allChannelsProvider).value;
    final byKey = {
      for (final c in channels ?? const <Channel>[]) c.identityKey: c,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          if (history.value?.isNotEmpty ?? false)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.clearHistory,
              onPressed: () => unawaited(_confirmClear(context, ref)),
            ),
        ],
      ),
      body: switch (history) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.emptyRecentTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.emptyRecentHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        AsyncData(:final value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (context, i) => _HistoryTile(
            entry: value[i],
            channel: byKey[value[i].channelKey],
            channelsLoaded: channels != null,
          ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(recentHistoryProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Resolve dependencies before awaiting the dialog: the widget (and
    // its ref) may be gone by the time it closes.
    final repository = ref.read(watchHistoryRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.clearHistoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clearHistory),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await repository.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.historyCleared)));
    }
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({
    required this.entry,
    required this.channel,
    required this.channelsLoaded,
  });

  final HistoryEntry entry;

  /// The live channel for [entry], or null when it vanished upstream.
  final Channel? channel;

  /// Whether the channel table has finished loading; while false a
  /// missing [channel] must not be reported as gone.
  final bool channelsLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final gone = channelsLoaded && channel == null;
    return ListTile(
      enabled: !gone,
      leading: const Icon(Icons.play_circle_outline),
      title: Text(
        entry.channelName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        gone
            ? '${_fmt(entry.watchedAt)} · ${l10n.historyChannelGone}'
            : _fmt(entry.watchedAt),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.delete,
        onPressed: () => unawaited(
          ref.read(watchHistoryRepositoryProvider).remove(entry.channelKey),
        ),
      ),
      onTap: gone ? null : () => context.pushNamed('player', extra: channel),
    );
  }

  static String _fmt(DateTime at) {
    final t = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
