import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/recording/application/providers.dart';

/// Lists, plays (best-effort) and deletes local recordings.
class RecordingsPage extends ConsumerWidget {
  /// Creates the page.
  const RecordingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordings = ref.watch(recordingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('录制')),
      body: switch (recordings) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: Text('还没有录制文件'),
        ),
        AsyncData(:final value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (context, i) => _RecordingTile(recording: value[i]),
        ),
        AsyncError(:final error) => Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RecordingTile extends ConsumerWidget {
  const _RecordingTile({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final duration = recording.durationAt(now);
    final subtitle = recording.isRecording
        ? '录制中 · ${_fmt(duration)}'
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
            tooltip: '播放',
            onPressed: () => _play(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
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
      ).showSnackBar(const SnackBar(content: Text('文件不存在，可能已被删除')));
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除录制'),
        content: Text('删除「${recording.channelName}」的录制文件？'),
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
      await ref.read(manageRecordingProvider).delete(recording);
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
