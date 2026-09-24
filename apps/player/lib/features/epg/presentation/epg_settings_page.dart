import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';

/// Page for configuring the EPG feed URL and syncing it.
class EpgSettingsPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const EpgSettingsPage({super.key});

  @override
  ConsumerState<EpgSettingsPage> createState() => _EpgSettingsPageState();
}

class _EpgSettingsPageState extends ConsumerState<EpgSettingsPage> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(epgUrlProvider)?.toString() ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = ref.watch(epgUrlProvider);
    final count = ref.watch(epgProgrammeCountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('EPG 节目单')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'XMLTV 源地址',
              hintText: 'https://example.com/epg.xml 或 .xml.gz',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持 XMLTV 格式（含 .gz 压缩）。留空则关闭 EPG。'
            ' vbskycn 已于 2025 年停止 EPG 服务，请自行配置公开源。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _saveAndSync,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_submitting ? '正在同步…' : '保存并同步'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _clear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清除 EPG 数据'),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('当前源'),
            subtitle: Text(url?.toString() ?? '未配置'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('未来 24 小时节目数'),
            subtitle: count.when(
              data: (n) => Text('$n'),
              loading: () => const Text('统计中…'),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndSync() async {
    final raw = _controller.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(epgSettingsProvider).setUrl(raw);
      final feed = await ref.read(syncEpgProvider)();
      ref
        ..invalidate(epgProgrammeCountProvider)
        ..invalidate(nowNextByEpgIdProvider);
      if (!mounted) return;
      final message = feed == null
          ? '已关闭 EPG'
          : 'EPG 同步完成：${feed.channels.length} 个频道 / '
                '${feed.programmes.length} 个节目';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _clear() async {
    await ref.read(epgSettingsProvider).setUrl(null);
    await ref.read(epgRepositoryProvider).clear();
    ref
      ..invalidate(epgProgrammeCountProvider)
      ..invalidate(nowNextByEpgIdProvider);
    if (!mounted) return;
    _controller.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除 EPG 数据')));
  }
}
