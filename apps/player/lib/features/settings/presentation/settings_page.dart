import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';

/// Settings hub: subscriptions, EPG, sync, detection, playback, theme.
class SettingsPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_play_outlined),
            title: const Text('订阅管理'),
            subtitle: const Text('启停、改名、删除、手动同步'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('subscription-management'),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: const Text('EPG 节目单'),
            subtitle: const Text('配置 XMLTV 源，显示「现在/接下来」'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('epg-settings'),
          ),
          ListTile(
            leading: const Icon(Icons.fiber_manual_record_outlined),
            title: const Text('录制文件'),
            subtitle: const Text('管理本地录制'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('recordings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('自动同步间隔'),
            subtitle: Text(_syncLabel(settings.syncInterval)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickSyncInterval(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.network_check_outlined),
            title: const Text('检测并发数'),
            subtitle: Text('${settings.probeConcurrency} 路并发'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickConcurrency(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('播放缓冲'),
            subtitle: Text(_bufferLabel(settings.bufferSizeBytes)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickBuffer(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('主题'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于 zeroTV'),
            subtitle: Text('开源免费 · 本地优先 · GPL-3.0'),
          ),
        ],
      ),
    );
  }

  static String _syncLabel(Duration? interval) {
    if (interval == null) return '仅手动';
    final hours = interval.inHours;
    return hours >= 1 ? '每 $hours 小时' : '每 ${interval.inMinutes} 分钟';
  }

  static String _bufferLabel(int bytes) {
    final mb = bytes ~/ (1024 * 1024);
    return '$mb MB';
  }

  static String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '跟随系统',
    };
  }

  Future<void> _pickSyncInterval(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).syncInterval;
    final options = <Duration?>[
      const Duration(hours: 1),
      const Duration(hours: 3),
      const Duration(hours: 6),
      const Duration(hours: 12),
      const Duration(hours: 24),
      null,
    ];
    final picked = await showModalBottomSheet<Duration?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in options)
              ListTile(
                title: Text(option == null ? '仅手动' : _syncLabel(option)),
                trailing: option == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    await ref.read(appSettingsProvider.notifier).setSyncInterval(picked);
  }

  Future<void> _pickConcurrency(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).probeConcurrency;
    final options = [4, 8, 16, 32, 64];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in options)
              ListTile(
                title: Text('$option 路并发'),
                trailing: option == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setProbeConcurrency(picked);
    }
  }

  Future<void> _pickBuffer(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).bufferSizeBytes;
    const options = [
      ('低延迟（8 MB）', 8 * 1024 * 1024),
      ('均衡（32 MB）', 32 * 1024 * 1024),
      ('稳定（64 MB）', 64 * 1024 * 1024),
      ('高缓冲（128 MB）', 128 * 1024 * 1024),
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (label, bytes) in options)
              ListTile(
                title: Text(label),
                trailing: bytes == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(bytes),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setBufferSize(picked);
    }
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).themeMode;
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeLabel(mode)),
                trailing: mode == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setThemeMode(picked);
    }
  }
}
