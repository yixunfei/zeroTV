import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/channel_filter.dart';
import 'package:zerotv_player/features/channel/application/custom_channel_providers.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/detection/application/probe_scan_controller.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/detection/application/run_availability_probe.dart';
import 'package:zerotv_player/features/epg/application/epg_guide.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/settings/presentation/disclaimer_gate.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(maybeShowDisclaimer(context, ref));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(bootstrapProvider, (_, next) {
      final failures = next.value;
      if (failures != null && failures.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.syncFailedKeep(failures.length))),
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
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: _onQueryChanged,
              )
            : Text(l10n.appTitle),
        actions: [
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.exitSearch,
              onPressed: _exitSearch,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.search,
              onPressed: _enterSearch,
            ),
            _ScanButton(
              onStart: () {
                final channels = ref.read(allChannelsProvider).value ?? [];
                unawaited(
                  ref.read(probeScanProvider.notifier).start(channels),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings,
              onPressed: () => context.goNamed('settings'),
            ),
          ],
        ],
      ),
      body: switch (bootstrap) {
        AsyncLoading() => _BootHint(l10n.syncingSources),
        AsyncError(:final error) => _BootError(error: error),
        AsyncData() => const _ChannelBrowser(),
      },
      floatingActionButton: MenuAnchor(
        builder: (context, controller, _) => FloatingActionButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          tooltip: l10n.add,
          child: const Icon(Icons.add),
        ),
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.playlist_add),
            onPressed: () => context.pushNamed('add-subscription'),
            child: Text(l10n.addSubscription),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.add_to_queue),
            onPressed: () => context.pushNamed('add-channel'),
            child: Text(l10n.addChannel),
          ),
        ],
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
          Text(
            AppLocalizations.of(context).syncFailedTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
            label: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }
}

class _ChannelBrowser extends ConsumerStatefulWidget {
  const _ChannelBrowser();

  @override
  ConsumerState<_ChannelBrowser> createState() => _ChannelBrowserState();
}

class _ChannelBrowserState extends ConsumerState<_ChannelBrowser> {
  /// Session-scoped dismissal of the resume banner.
  bool _resumeDismissed = false;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(allGroupsProvider).value ?? const <String>[];
    final filter = ref.watch(channelFilterProvider);
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final lastWatched = ref.watch(lastWatchedChannelProvider);
    final scan = ref.watch(probeScanProvider);
    final showResume =
        !_resumeDismissed && filter is FilterAll && lastWatched != null;
    return Column(
      children: [
        if (showResume)
          _ResumeBanner(
            channel: lastWatched,
            onDismiss: () => setState(() => _resumeDismissed = true),
          ),
        if (scan is ProbeScanRunning)
          _ScanProgressBanner(progress: scan.progress),
        if (filter is! FilterSearch)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: AppLocalizations.of(context).filterAll,
                  selected: filter is FilterAll,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterAll(),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).filterFavorites,
                  selected: filter is FilterFavorites,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterFavorites(),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).filterRecent,
                  selected: filter is FilterRecent,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterRecent(),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).filterAvailable,
                  selected: filter is FilterAvailable,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterAvailable(),
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
            AsyncError(:final error) => Center(
              child: Text(AppLocalizations.of(context).loadFailed('$error')),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.channel, required this.onDismiss});

  final Channel channel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: Text(AppLocalizations.of(context).resumeTitle(channel.name)),
        subtitle: Text(AppLocalizations.of(context).resumeSubtitle),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: AppLocalizations.of(context).close,
          onPressed: onDismiss,
        ),
        onTap: () => context.pushNamed('player', extra: channel),
      ),
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

/// App-bar action that starts a batch availability scan and reflects
/// its progress.
class _ScanButton extends ConsumerWidget {
  const _ScanButton({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(probeScanProvider);
    if (scan is ProbeScanRunning) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.network_check_outlined),
      tooltip: AppLocalizations.of(context).probeScan,
      onPressed: onStart,
    );
  }
}

/// Thin progress bar shown while a batch scan is running.
class _ScanProgressBanner extends StatelessWidget {
  const _ScanProgressBanner({required this.progress});

  final ProbeProgress progress;

  @override
  Widget build(BuildContext context) {
    final total = progress.total;
    final value = total == 0 ? 0.0 : progress.completed / total;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering, size: 18),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(
                    context,
                  ).probeScanning(progress.completed, total),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(value: value),
        ],
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
    final probe = ref.watch(probeResultsProvider).value?[channel.identityKey];
    final nowNext = ref.watch(epgIndexProvider).value?.forChannel(channel);
    final isManual =
        ref
            .watch(manualChannelKeysProvider)
            .value
            ?.contains(
              channel.identityKey,
            ) ??
        false;
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                channel.groupTitle ?? AppLocalizations.of(context).ungrouped,
              ),
              if (probe != null) ...[
                const SizedBox(width: 8),
                _ProbeStatusDot(status: probe.status),
              ],
            ],
          ),
          if (nowNext != null && (nowNext.now != null || nowNext.next != null))
            _NowNextLine(nowNext: nowNext),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : null,
            ),
            tooltip: isFavorite
                ? AppLocalizations.of(context).unfavorite
                : AppLocalizations.of(context).favorite,
            onPressed: () =>
                unawaited(ref.read(toggleFavoriteProvider)(channel)),
          ),
          if (isManual)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: AppLocalizations.of(context).deleteChannel,
              onPressed: () => unawaited(_confirmDelete(context, ref)),
            ),
        ],
      ),
      onTap: () => context.pushNamed('player', extra: channel),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteChannel),
        content: Text(
          AppLocalizations.of(context).deleteChannelBody(channel.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(removeCustomChannelProvider)(channel.identityKey);
    }
  }
}

/// Compact "now / next" line shown under a channel whose EPG matched.
class _NowNextLine extends StatelessWidget {
  const _NowNextLine({required this.nowNext});

  final NowNext nowNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
    );
    final now = nowNext.now?.title;
    final next = nowNext.next?.title;
    final l10n = AppLocalizations.of(context);
    final text = switch ((now, next)) {
      (final n?, final x?) => l10n.nowNextBoth(n, x),
      (final n?, null) => l10n.nowOnly(n),
      (null, final x?) => l10n.nextOnly(x),
      _ => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Small colored dot summarizing the latest probe status of a channel.
class _ProbeStatusDot extends StatelessWidget {
  const _ProbeStatusDot({required this.status});

  final ProbeStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (color, label) = switch (status) {
      ProbeStatus.ok => (Colors.green, l10n.probeOk),
      ProbeStatus.timeout => (Colors.orange, l10n.probeTimeout),
      ProbeStatus.dead => (Colors.red, l10n.probeDead),
      ProbeStatus.unsupported => (Colors.grey, l10n.probeUnsupported),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.filter});

  final ChannelFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, hint) = switch (filter) {
      FilterFavorites() => (l10n.emptyFavoritesTitle, l10n.emptyFavoritesHint),
      FilterRecent() => (l10n.emptyRecentTitle, l10n.emptyRecentHint),
      FilterSearch(:final query) => (
        l10n.emptySearchTitle(query),
        l10n.emptySearchHint,
      ),
      FilterAvailable() => (l10n.emptyAvailableTitle, l10n.emptyAvailableHint),
      _ => (l10n.emptyChannelsTitle, l10n.emptyChannelsHint),
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
