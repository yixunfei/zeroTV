import 'package:flutter/material.dart';

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
        children: const [
          ListTile(
            leading: Icon(Icons.sync_outlined),
            title: Text('订阅同步'),
            subtitle: Text('同步间隔、镜像加速（M2 开放）'),
          ),
          ListTile(
            leading: Icon(Icons.network_check_outlined),
            title: Text('可用性检测'),
            subtitle: Text('并发数、超时（M2 开放）'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于 zeroTV'),
            subtitle: Text('开源免费 · 本地优先 · GPL-3.0'),
          ),
        ],
      ),
    );
  }
}
