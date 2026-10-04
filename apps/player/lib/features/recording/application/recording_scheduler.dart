import 'dart:async';

import 'package:iptv_core/iptv_core.dart';
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

/// Fires and stops EPG-based scheduled recordings while the app runs.
///
/// There is no reliable way to keep capturing a live stream after the
/// process exits (WorkManager cannot hold a long-lived recording), so
/// schedules only fire while the app is running — a window missed with
/// the app closed is marked [ScheduledRecordingState.failed] on the next
/// launch instead of pretending it was captured.
class RecordingScheduler {
  /// Creates the scheduler. [tick] is the polling interval; it is
  /// injectable so tests can drive [tickNow] directly.
  RecordingScheduler({
    required ScheduledRecordingRepository schedules,
    required ChannelRepository channels,
    required ManageRecording manage,
    Duration tick = const Duration(seconds: 15),
  }) : _schedules = schedules,
       _channels = channels,
       _manage = manage,
       _tick = tick;

  final ScheduledRecordingRepository _schedules;
  final ChannelRepository _channels;
  final ManageRecording _manage;
  final Duration _tick;

  Timer? _timer;
  final _captures = <String, _ActiveCapture>{};
  bool _ticking = false;

  /// Starts polling. Idempotent; also performs an immediate pass so a
  /// schedule whose window opened during startup fires right away.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_tick, (_) => unawaited(tickNow()));
    unawaited(tickNow());
  }

  /// Stops polling. Running captures are left alone — they belong to
  /// [ManageRecording] and finish with the process.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Schedules [programme] on [channel]. Returns null when an active
  /// schedule for the same channel and start time already exists.
  Future<ScheduledRecording?> schedule(
    Channel channel,
    EpgProgram programme,
  ) async {
    final existing = await _schedules.watchAll().first;
    for (final s in existing) {
      if (s.isActive &&
          s.channelKey == channel.identityKey &&
          s.startAt.isAtSameMomentAs(programme.start)) {
        return null;
      }
    }
    final scheduled = ScheduledRecording(
      id: const Uuid().v4(),
      channelKey: channel.identityKey,
      channelName: channel.name,
      streamUrl: channel.streamUrl,
      title: programme.title,
      startAt: programme.start,
      endAt: programme.stop,
      createdAt: DateTime.now(),
    );
    await _schedules.upsert(scheduled);
    // A programme that is already airing fires on the next tick; nudge it
    // so the user is not left staring at a 15-second delay.
    if (!scheduled.startAt.isAfter(DateTime.now())) unawaited(tickNow());
    return scheduled;
  }

  /// Cancels [scheduled]: a running capture is stopped first, then the
  /// row is marked cancelled.
  Future<void> cancel(ScheduledRecording scheduled) async {
    await _stopCapture(scheduled.id, ScheduledRecordingState.cancelled);
    await _schedules.markState(
      scheduled.id,
      ScheduledRecordingState.cancelled,
    );
  }

  /// One scheduling pass: fire due schedules, stop captures whose window
  /// closed, expire missed windows. Public (instead of timer-private) so
  /// tests can drive it deterministically; safe against re-entrant ticks.
  Future<void> tickNow() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final now = DateTime.now();
      final all = await _schedules.watchAll().first;
      for (final s in all) {
        final hasCapture = _captures.containsKey(s.id);
        final windowOpen = s.endAt.isAfter(now);
        // A "recording" row without a live capture means the process was
        // killed mid-capture (or the stream died and the done-callback
        // already ran): treat it as pending again so an open window
        // resumes and a closed one expires below.
        final dueToFire =
            (s.isPending || (s.isRecording && !hasCapture)) &&
            !s.startAt.isAfter(now);
        if (dueToFire && windowOpen) {
          await _fire(s);
        } else if (!windowOpen && hasCapture) {
          // The capture ran to the end of the programme window.
          await _stopCapture(s.id, ScheduledRecordingState.done);
        } else if (!windowOpen && s.isActive) {
          // Window fully missed while the app was closed (or a dead
          // capture was never finalized).
          await _stopCapture(s.id, ScheduledRecordingState.failed);
          await _schedules.markState(s.id, ScheduledRecordingState.failed);
        }
      }
    } finally {
      _ticking = false;
    }
  }

  Future<void> _fire(ScheduledRecording s) async {
    // Resolve the live channel row: its stream URL and HTTP headers are
    // fresher than the snapshot taken when the schedule was created.
    final target =
        await _resolveChannel(s) ??
        Channel(name: s.channelName, streamUrl: s.streamUrl);
    try {
      final result = await _manage.start(target);
      _captures[s.id] = _ActiveCapture(
        recording: result.recording,
        handle: result.handle,
      );
      await _schedules.markState(s.id, ScheduledRecordingState.recording);
      // If the stream ends on its own before the window closes (EOF or
      // network error), finalize the schedule as well — a partial capture
      // still counts as done, matching the manual-recording semantics.
      unawaited(
        result.done.then(
          (_) => _stopCapture(s.id, ScheduledRecordingState.done),
          onError: (_) => _stopCapture(s.id, ScheduledRecordingState.failed),
        ),
      );
    } on Object {
      await _schedules.markState(s.id, ScheduledRecordingState.failed);
    }
  }

  Future<Channel?> _resolveChannel(ScheduledRecording s) async {
    try {
      final all = await _channels.watchAll().first;
      for (final c in all) {
        if (c.identityKey == s.channelKey) return c;
      }
    } on Object {
      // A lookup failure must not block the fallback snapshot below.
    }
    return null;
  }

  /// Stops the live capture for [id] (when any) and marks the schedule
  /// [state]. No-op when another path already finalized this schedule.
  Future<void> _stopCapture(String id, ScheduledRecordingState state) async {
    final active = _captures.remove(id);
    if (active == null) return;
    await _manage.stop(active.recording, active.handle);
    await _schedules.markState(id, state);
  }
}

class _ActiveCapture {
  const _ActiveCapture({required this.recording, required this.handle});

  final Recording recording;
  final RecordingHandle handle;
}
