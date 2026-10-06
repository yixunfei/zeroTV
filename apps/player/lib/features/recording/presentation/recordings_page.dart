import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/widgets/error_view.dart';
import 'package:zerotv_player/features/recording/application/providers.dart';
import 'package:zerotv_player/features/shared/presentation/error_localization.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Lists, plays (best-effort) and deletes local recordings.
class RecordingsPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const RecordingsPage({super.key});

  @override
  ConsumerState<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends ConsumerState<RecordingsPage> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recordings = ref.watch(recordingsProvider);
    final anyActive = recordings.value?.any((r) => r.isRecording) ?? false;
    if (anyActive && _ticker == null) {
      // While any capture is running, tick once a second so its duration
      // keeps advancing (the DB row is only finalized on stop).
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!anyActive && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.recordingsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.recordingsTabFiles),
              Tab(text: l10n.recordingsTabScheduled),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            switch (recordings) {
              AsyncData(:final value) when value.isEmpty => Center(
                child: Text(l10n.noRecordings),
              ),
              AsyncData(:final value) => ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, i) =>
                    _RecordingTile(recording: value[i]),
              ),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(recordingsProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
            const _ScheduledRecordingsList(),
          ],
        ),
      ),
    );
  }
}

/// The scheduled-recordings tab: upcoming windows first by start time,
/// with cancel (active) and delete (finished) actions.
class _ScheduledRecordingsList extends ConsumerWidget {
  const _ScheduledRecordingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheduled = ref.watch(scheduledRecordingsProvider);
    return switch (scheduled) {
      AsyncData(:final value) when value.isEmpty => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.noScheduledRecordings),
            const SizedBox(height: 8),
            Text(
              l10n.noScheduledRecordingsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      AsyncData(:final value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, i) => _ScheduledTile(scheduled: value[i]),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(scheduledRecordingsProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _ScheduledTile extends ConsumerWidget {
  const _ScheduledTile({required this.scheduled});

  final ScheduledRecording scheduled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    String fmtTime(DateTime t) => local.formatTimeOfDay(
      TimeOfDay.fromDateTime(t.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final window =
        '${local.formatShortDate(scheduled.startAt.toLocal())} '
        '${fmtTime(scheduled.startAt)}–${fmtTime(scheduled.endAt)}';
    return ListTile(
      leading: Icon(_stateIcon(scheduled.state), color: _stateColor(theme)),
      title: Text(
        scheduled.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${l10n.scheduledMeta(scheduled.channelName, window)} · '
        '${_stateLabel(l10n)}',
      ),
      trailing: scheduled.isActive
          ? IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: l10n.cancelSchedule,
              onPressed: () => unawaited(_confirmCancel(context, ref)),
            )
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => unawaited(
                ref
                    .read(scheduledRecordingRepositoryProvider)
                    .remove(scheduled.id),
              ),
            ),
    );
  }

  IconData _stateIcon(ScheduledRecordingState state) {
    return switch (state) {
      ScheduledRecordingState.pending => Icons.schedule,
      ScheduledRecordingState.recording => Icons.fiber_manual_record,
      ScheduledRecordingState.done => Icons.check_circle_outline,
      ScheduledRecordingState.failed => Icons.error_outline,
      ScheduledRecordingState.cancelled => Icons.block,
    };
  }

  Color? _stateColor(ThemeData theme) {
    return switch (scheduled.state) {
      ScheduledRecordingState.recording => Colors.red,
      ScheduledRecordingState.failed => theme.colorScheme.error,
      _ => null,
    };
  }

  String _stateLabel(AppLocalizations l10n) {
    return switch (scheduled.state) {
      ScheduledRecordingState.pending => l10n.scheduleStatePending,
      ScheduledRecordingState.recording => l10n.scheduleStateRecording,
      ScheduledRecordingState.done => l10n.scheduleStateDone,
      ScheduledRecordingState.failed => l10n.scheduleStateFailed,
      ScheduledRecordingState.cancelled => l10n.scheduleStateCancelled,
    };
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    // Resolve dependencies before awaiting the dialog: the tile may be
    // gone by the time it closes.
    final scheduler = ref.read(recordingSchedulerProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.cancelSchedule),
          content: Text(l10n.cancelScheduleBody(scheduled.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await scheduler.cancel(scheduled);
    }
  }
}

class _RecordingTile extends ConsumerWidget {
  const _RecordingTile({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final duration = recording.durationAt(now);
    final l10n = AppLocalizations.of(context);
    final subtitle = recording.isRecording
        ? l10n.recordingNow(_fmt(duration))
        : '${_fmt(duration)} · ${_size(recording.sizeBytes)}';
    return ListTile(
      leading: Icon(
        recording.isRecording
            ? Icons.fiber_manual_record
            : Icons.movie_outlined,
        color: recording.isRecording ? Colors.red : null,
      ),
      title: Text(recording.channelName),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: l10n.play,
            onPressed: () => _play(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => unawaited(_confirmDelete(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final file = File(recording.filePath);
    if (!file.existsSync()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).fileMissing)),
      );
      return;
    }
    final channel = Channel(
      name: recording.channelName,
      streamUrl: file.uri.toString(),
    );
    if (!context.mounted) return;
    await context.pushNamed('player', extra: channel);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Resolve dependencies before awaiting the dialog: the widget (and
    // its ref) may be gone by the time it closes.
    final manage = ref.read(manageRecordingProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.deleteRecording),
          content: Text(l10n.deleteRecordingBody(recording.channelName)),
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
      try {
        await manage.delete(recording);
      } on Object catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).deleteFailed(
                  localizedErrorText(AppLocalizations.of(context), e),
                ),
              ),
            ),
          );
        }
      }
    }
  }

  static String _fmt(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
