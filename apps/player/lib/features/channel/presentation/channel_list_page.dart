import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/widgets/error_view.dart';
import 'package:zerotv_player/features/channel/application/channel_filter.dart';
import 'package:zerotv_player/features/channel/application/custom_channel_providers.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/channel/presentation/channel_logo.dart';
import 'package:zerotv_player/features/detection/application/probe_scan_controller.dart';
import 'package:zerotv_player/features/detection/application/run_availability_probe.dart';
import 'package:zerotv_player/features/epg/application/epg_guide.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/settings/presentation/disclaimer_gate.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/background_sync_controller.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Home page: grouped channel list. Bootstrap only performs fast local
/// seeding; the initial subscription sync runs in the background (see
/// [backgroundSyncControllerProvider]) so cached content renders
/// immediately and the page never blocks on the network.
class ChannelListPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ChannelListPage({super.key});

  @override
  ConsumerState<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends ConsumerState<ChannelListPage> {
  static const _searchDebounce = Duration(milliseconds: 300);

  bool _searching = false;
  ChannelFilter? _filterBeforeSearch;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearch() {
    _filterBeforeSearch = ref.read(channelFilterProvider);
    setState(() => _searching = true);
    ref.read(channelFilterProvider.notifier).current = const FilterSearch('');
  }

  void _exitSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _searching = false);
    ref.read(channelFilterProvider.notifier).current =
        _filterBeforeSearch ?? const FilterAvailable();
    _filterBeforeSearch = null;
  }

  void _onQueryChanged(String query) {
    // Debounce: filtering scans every channel (plus EPG now/next) on each
    // keystroke otherwise.
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      ref.read(channelFilterProvider.notifier).current = FilterSearch(query);
    });
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
    ref
      ..listen(backgroundSyncControllerProvider, (_, next) {
        if (next case BackgroundSyncDone(
          :final failures,
        ) when failures.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.syncFailedKeep(failures.length))),
          );
        }
      })
      ..listen(probeScanProvider, (_, next) {
        if (next case ProbeScanDone(:final available, :final total)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.probeScanDoneMsg(available, total))),
          );
        }
      })
      ..watch(bootstrapProvider);
    // Keep bootstrap alive for local seeding, but never gate the first frame
    // on it. The browser and its background-sync banner remain interactive.
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
                unawaited(() async {
                  List<Channel> channels;
                  try {
                    channels = await ref.read(allChannelsProvider.future);
                  } on Object {
                    channels = const [];
                  }
                  if (!mounted) return;
                  await ref.read(probeScanProvider.notifier).start(channels);
                }());
              },
              onCancel: () => ref.read(probeScanProvider.notifier).cancel(),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings,
              onPressed: () => context.goNamed('settings'),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.menuMore,
              onSelected: (route) => context.pushNamed(route),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'guide',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(l10n.guideTitle),
                  ),
                ),
                PopupMenuItem(
                  value: 'favorites',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.star_border),
                    title: Text(l10n.favoritesTitle),
                  ),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_outlined),
                    title: Text(l10n.historyTitle),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      // Bootstrap only covers local seeding; even if it fails we still
      // show the browser (empty state) rather than trapping the user on
      // an error page. Sync progress/failures surface via the banner and
      // snackbar wired to backgroundSyncControllerProvider.
      body: const _ChannelBrowser(),
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

class _ChannelBrowser extends ConsumerStatefulWidget {
  const _ChannelBrowser();

  @override
  ConsumerState<_ChannelBrowser> createState() => _ChannelBrowserState();
}

class _ChannelBrowserState extends ConsumerState<_ChannelBrowser> {
  /// Session-scoped dismissal of the resume banner.
  bool _resumeDismissed = false;

  /// Pull-to-refresh: manually re-syncs every syncable subscription
  /// (ignoring schedule and auto-sync toggles) and reports failures.
  Future<void> _refreshSubscriptions() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backgroundSyncControllerProvider.notifier).run(all: true);
      final state = ref.read(backgroundSyncControllerProvider);
      final failures = state is BackgroundSyncDone
          ? state.failures
          : const <SyncFailure>[];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failures.isEmpty
                ? l10n.refreshDone
                : l10n.syncFailedKeep(failures.length),
          ),
        ),
      );
    } on Object catch (e) {
      // Failures of individual subscriptions are reported above; this
      // only catches an outright error (e.g. the DB read failed) so it
      // doesn't escape the RefreshIndicator callback.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.syncFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(allGroupsProvider).value ?? const <String>[];
    final filter = ref.watch(channelFilterProvider);
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final lastWatched = ref.watch(lastWatchedChannelProvider);
    final scan = ref.watch(probeScanProvider);
    final backgroundSync = ref.watch(backgroundSyncControllerProvider);
    final showResume =
        !_resumeDismissed &&
        (filter is FilterAll || filter is FilterAvailable) &&
        lastWatched != null;
    return Column(
      children: [
        if (backgroundSync case BackgroundSyncRunning(
          :final completed,
          :final total,
        ))
          _SyncingBanner(completed: completed, total: total),
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
                  label: AppLocalizations.of(context).filterAvailable,
                  selected: filter is FilterAvailable,
                  onSelected: () =>
                      ref.read(channelFilterProvider.notifier).current =
                          const FilterAvailable(),
                ),
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
          child: RefreshIndicator(
            onRefresh: _refreshSubscriptions,
            child: switch (channelsAsync) {
              AsyncData(:final value) when value.isEmpty => ListView(
                // Keeps pull-to-refresh reachable on the empty state.
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height / 2,
                    child: _EmptyHint(
                      filter: filter,
                      hasProbeResults:
                          ref
                              .watch(effectiveProbeResultsProvider)
                              .value
                              ?.isNotEmpty ??
                          false,
                    ),
                  ),
                ],
              ),
              AsyncData(:final value) => _ChannelList(channels: value),
              AsyncError(:final error) => ErrorView(
                error: error,
                // Invalidate the underlying stream providers; the list
                // view itself is purely derived and would just re-read
                // the cached error.
                onRetry: () {
                  ref
                    ..invalidate(allChannelsProvider)
                    ..invalidate(deadKeysProvider);
                },
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ],
    );
  }
}

/// Slim non-blocking banner shown while the background subscription
/// sync is running; the list below stays fully interactive.
class _SyncingBanner extends StatelessWidget {
  const _SyncingBanner({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  total == 0
                      ? AppLocalizations.of(context).syncingSources
                      : '${AppLocalizations.of(context).syncingSources} '
                            '$completed/$total',
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: total == 0 ? null : completed / total,
          ),
        ],
      ),
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
  const _ScanButton({required this.onStart, required this.onCancel});

  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(probeScanProvider);
    final l10n = AppLocalizations.of(context);
    if (scan is ProbeScanRunning) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancelScan,
            onPressed: onCancel,
          ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.network_check_outlined),
      tooltip: l10n.probeScan,
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
      physics: const AlwaysScrollableScrollPhysics(),
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
    final favorites = ref.watch(favoriteKeysProvider).value ?? const <String>{};
    final isFavorite = favorites.contains(channel.identityKey);
    final probe = ref
        .watch(effectiveProbeResultsProvider)
        .value?[channel.identityKey];
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
      leading: ChannelLogo(logoUrl: channel.logoUrl),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  channel.groupTitle ?? AppLocalizations.of(context).ungrouped,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (probe != null) _ProbeStatusBadge(result: probe),
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
      onLongPress: () => unawaited(_showChannelActions(context, ref)),
    );
  }

  Future<void> _showChannelActions(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final isManual =
        ref
            .read(manualChannelKeysProvider)
            .value
            ?.contains(channel.identityKey) ??
        false;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (isManual)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.editChannel),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            ListTile(
              leading: const Icon(Icons.tv_off_outlined),
              title: Text(l10n.markDead),
              subtitle: Text(l10n.markDeadHint),
              onTap: () => Navigator.of(context).pop('dead'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'edit') {
      await context.pushNamed('edit-channel', extra: channel);
    } else if (action == 'dead') {
      await ref.read(toggleDeadProvider)(channel, currentlyDead: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.markedDead(channel.name))),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Resolve dependencies before awaiting the dialog: the tile may be
    // gone from the tree (list update, page pop) by the time it closes.
    final remove = ref.read(removeCustomChannelProvider);
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
      await remove(channel.identityKey);
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
class _ProbeStatusBadge extends StatelessWidget {
  const _ProbeStatusBadge({required this.result});

  final ProbeResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (color, label) = switch (result.status) {
      ProbeStatus.ok => (Colors.green, l10n.probeOk),
      ProbeStatus.timeout => (Colors.orange, l10n.probeTimeout),
      ProbeStatus.dead => (Colors.red, l10n.probeDead),
      ProbeStatus.unsupported => (Colors.grey, l10n.probeUnsupported),
    };
    final latency = result.latency;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: .42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              latency == null ? label : '$label · ${latency.inMilliseconds} ms',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.filter, required this.hasProbeResults});

  final ChannelFilter filter;
  final bool hasProbeResults;

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
      FilterAvailable() when hasProbeResults => (
        l10n.emptyAvailableTitle,
        l10n.emptyAvailableHint,
      ),
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
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (filter is FilterAll) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.pushNamed('add-subscription'),
              icon: const Icon(Icons.playlist_add),
              label: Text(l10n.addSubscription),
            ),
          ],
        ],
      ),
    );
  }
}
