import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/widgets/error_view.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/recording/application/providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Per-channel programme guide: pick a channel, browse its programme
/// list day by day. The currently airing programme is highlighted.
class EpgGuidePage extends ConsumerStatefulWidget {
  /// Creates the page.
  const EpgGuidePage({super.key});

  @override
  ConsumerState<EpgGuidePage> createState() => _EpgGuidePageState();
}

class _EpgGuidePageState extends ConsumerState<EpgGuidePage> {
  Channel? _channel;
  DateTime _day = DateTime.now();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isToday => _dateOnly(_day) == _dateOnly(DateTime.now());

  void _shiftDay(int days) {
    setState(() => _day = _dateOnly(_day).add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = ref.watch(epgIndexProvider).value;
    final channels = ref.watch(aliveChannelsProvider).value ?? const [];
    final matched = [
      for (final c in channels)
        if (index?.epgIdFor(c) != null) c,
    ];
    final channel = _channel ?? (matched.isEmpty ? null : matched.first);
    final epgId = channel == null ? null : index?.epgIdFor(channel);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: matched.isEmpty || channel == null
              ? null
              : () => _pickChannel(matched, channel),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  channel?.name ?? l10n.guideTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (matched.isNotEmpty) const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _DayBar(
            day: _day,
            isToday: _isToday,
            onShift: _shiftDay,
            onToday: () => setState(() => _day = _dateOnly(DateTime.now())),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(
              l10n,
              matched: matched,
              epgId: epgId,
              channel: channel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n, {
    required List<Channel> matched,
    required String? epgId,
    required Channel? channel,
  }) {
    if (matched.isEmpty) {
      return _GuideHint(
        icon: Icons.event_note_outlined,
        title: l10n.guideNoEpg,
        actionLabel: l10n.epgTitle,
        onAction: () => context.pushNamed('epg-settings'),
      );
    }
    if (epgId == null) {
      return _GuideHint(
        icon: Icons.search_off_outlined,
        title: l10n.guideNoMatch,
      );
    }
    final programmes = ref.watch(
      channelGuideProvider((epgId: epgId, day: _day)),
    );
    return switch (programmes) {
      AsyncData(:final value) when value.isEmpty => _GuideHint(
        icon: Icons.event_busy_outlined,
        title: l10n.guideEmpty,
      ),
      AsyncData(:final value) => _ProgrammeList(
        programmes: value,
        channel: channel,
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(
          channelGuideProvider((epgId: epgId, day: _day)),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Future<void> _pickChannel(List<Channel> matched, Channel current) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<Channel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.guidePickChannel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in matched)
                    ListTile(
                      title: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: c.identityKey == current.identityKey
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.of(context).pop(c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _channel = picked);
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.isToday,
    required this.onShift,
    required this.onToday,
  });

  final DateTime day;
  final bool isToday;
  final ValueChanged<int> onShift;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = isToday
        ? l10n.today
        : MaterialLocalizations.of(context).formatShortDate(day);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onShift(-1),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (!isToday) TextButton(onPressed: onToday, child: Text(l10n.today)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onShift(1),
          ),
        ],
      ),
    );
  }
}

class _ProgrammeList extends StatelessWidget {
  const _ProgrammeList({required this.programmes, required this.channel});

  final List<EpgProgram> programmes;
  final Channel? channel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView.builder(
      itemCount: programmes.length,
      itemBuilder: (context, i) {
        final p = programmes[i];
        final airing = !p.start.isAfter(now) && p.stop.isAfter(now);
        return _ProgrammeTile(
          programme: p,
          airing: airing,
          channel: channel,
        );
      },
    );
  }
}

class _ProgrammeTile extends ConsumerWidget {
  const _ProgrammeTile({
    required this.programme,
    required this.airing,
    required this.channel,
  });

  final EpgProgram programme;
  final bool airing;

  /// The channel the guide is showing; null only in defensive states
  /// where scheduling is meaningless and the button stays hidden.
  final Channel? channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    String fmt(DateTime t) => local.formatTimeOfDay(
      TimeOfDay.fromDateTime(t.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final schedulable =
        channel != null && programme.stop.isAfter(DateTime.now());
    final scheduled =
        schedulable &&
        (ref
                .watch(scheduledRecordingsProvider)
                .value
                ?.any(
                  (s) =>
                      s.isActive &&
                      s.channelKey == channel!.identityKey &&
                      s.startAt.isAtSameMomentAs(programme.start),
                ) ??
            false);
    return Container(
      decoration: airing
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 4),
              ),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            )
          : null,
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(fmt(programme.start), style: theme.textTheme.titleSmall),
            Text(
              fmt(programme.stop),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        title: Text(programme.title, maxLines: 2),
        subtitle: programme.description == null
            ? null
            : Text(
                programme.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: !schedulable
            ? null
            : IconButton(
                icon: Icon(scheduled ? Icons.event_available : Icons.alarm_add),
                tooltip: AppLocalizations.of(context).scheduleRecording,
                onPressed: scheduled
                    ? null
                    : () => unawaited(_schedule(ref, context)),
              ),
        onTap: programme.description == null
            ? null
            : () => unawaited(_showDescription(context)),
      ),
    );
  }

  Future<void> _schedule(WidgetRef ref, BuildContext context) async {
    final target = channel;
    if (target == null) return;
    // Resolve everything context-derived before the async gap.
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(recordingSchedulerProvider)
        .schedule(target, programme);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? l10n.scheduledRecordingExists
              : l10n.scheduledRecordingAdded(programme.title),
        ),
      ),
    );
  }

  Future<void> _showDescription(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(programme.title),
        content: SingleChildScrollView(
          child: Text(programme.description ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

class _GuideHint extends StatelessWidget {
  const _GuideHint({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
