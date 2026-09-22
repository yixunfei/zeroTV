import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Settings page. M0 shell with section placeholders;
/// real options land with their respective milestones.
class SettingsPage extends StatelessWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          const ListTile(
            leading: Icon(Icons.sync_outlined),
            title: Text('订阅同步'),
            subtitle: Text('同步间隔、镜像加速（M2 开放）'),
          ),
          const ListTile(
            leading: Icon(Icons.network_check_outlined),
            title: Text('可用性检测'),
            subtitle: Text('并发数、超时（M2 开放）'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于 zeroTV'),
            subtitle: Text('开源免费 · 本地优先 · GPL-3.0'),
          ),
        ],
      ),
    );
  }
}
