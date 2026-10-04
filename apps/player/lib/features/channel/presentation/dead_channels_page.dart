import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/widgets/error_view.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Management page for channels the user marked as dead: revive them
/// one by one, or clean up marks whose channel disappeared upstream.
class DeadChannelsPage extends ConsumerWidget {
  /// Creates the page.
  const DeadChannelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dead = ref.watch(deadChannelsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deadChannelsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: l10n.cleanOrphanedDead,
            onPressed: () => unawaited(_cleanOrphans(context, ref)),
          ),
        ],
      ),
      body: switch (dead) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 72,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.emptyDeadTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.emptyDeadHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        AsyncData(:final value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (context, i) => _DeadTile(entry: value[i]),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(deadChannelsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _cleanOrphans(BuildContext context, WidgetRef ref) async {
    // Resolve dependencies before awaiting: the widget may be gone when
    // the future completes.
    final repository = ref.read(deadChannelRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    List<Channel>? channels;
    try {
      channels = await ref.read(allChannelsProvider.future);
    } on Object {
      // Leave the marks alone when the channel table is unavailable.
    }
    if (!context.mounted) return;
    if (channels == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.channelsNotLoadedYet)),
      );
      return;
    }
    final existing = {for (final c in channels) c.identityKey};
    await repository.clearOrphans(existing);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).orphanDeadCleaned),
        ),
      );
    }
  }
}

class _DeadTile extends ConsumerWidget {
  const _DeadTile({required this.entry});

  final DeadChannel entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.tv_off_outlined),
      title: Text(
        entry.channelName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.streamUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.restore),
        label: Text(l10n.revive),
        onPressed: () => unawaited(
          ref.read(deadChannelRepositoryProvider).unmark(entry.channelKey),
        ),
      ),
    );
  }
}
