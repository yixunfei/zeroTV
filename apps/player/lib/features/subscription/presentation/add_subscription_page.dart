import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// Page for adding a subscription: remote URL, local file, or pasted text.
class AddSubscriptionPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AddSubscriptionPage({super.key});

  @override
  ConsumerState<AddSubscriptionPage> createState() =>
      _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends ConsumerState<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _textController = TextEditingController();

  SubscriptionKind _kind = SubscriptionKind.remoteUrl;
  String? _pickedFilePath;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加订阅')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<SubscriptionKind>(
              segments: const [
                ButtonSegment(
                  value: SubscriptionKind.remoteUrl,
                  icon: Icon(Icons.link),
                  label: Text('URL'),
                ),
                ButtonSegment(
                  value: SubscriptionKind.localFile,
                  icon: Icon(Icons.folder_open),
                  label: Text('本地文件'),
                ),
                ButtonSegment(
                  value: SubscriptionKind.pastedText,
                  icon: Icon(Icons.content_paste),
                  label: Text('粘贴文本'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.single),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '名称',
                hintText: _kind == SubscriptionKind.pastedText
                    ? '必填'
                    : '留空则自动命名',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (_kind == SubscriptionKind.pastedText &&
                    (v == null || v.trim().isEmpty)) {
                  return '粘贴文本订阅需要名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ..._kindFields(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_done),
              label: Text(_submitting ? '正在同步…' : '添加并同步'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _kindFields() {
    switch (_kind) {
      case SubscriptionKind.remoteUrl:
        return [
          TextFormField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '播放列表 URL',
              hintText: 'https://example.com/list.m3u',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final uri = Uri.tryParse(v?.trim() ?? '');
              if (uri == null ||
                  !(uri.isScheme('HTTP') || uri.isScheme('HTTPS'))) {
                return '请输入合法的 http(s) 地址';
              }
              return null;
            },
          ),
        ];
      case SubscriptionKind.localFile:
        return [
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickFile,
            icon: const Icon(Icons.upload_file),
            label: Text(_pickedFilePath ?? '选择 M3U/TXT 文件'),
          ),
          if (_pickedFilePath == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '尚未选择文件',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ];
      case SubscriptionKind.pastedText:
        return [
          TextFormField(
            controller: _textController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'M3U 内容',
              hintText: '#EXTM3U\n#EXTINF:-1,频道名\nhttp://…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请粘贴播放列表内容';
              return null;
            },
          ),
        ];
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '选择播放列表文件',
      type: FileType.custom,
      allowedExtensions: const ['m3u', 'm3u8', 'txt'],
    );
    final path = file?.path;
    if (path != null) {
      setState(() => _pickedFilePath = path);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final add = ref.read(addSubscriptionProvider);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = switch (_kind) {
        SubscriptionKind.remoteUrl => await add.fromUrl(
          name: _nameController.text,
          url: Uri.parse(_urlController.text.trim()),
        ),
        SubscriptionKind.localFile => await add.fromFile(
          name: _nameController.text,
          path: _requireFilePath(),
        ),
        SubscriptionKind.pastedText => await add.fromText(
          name: _nameController.text,
          content: _textController.text,
        ),
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加订阅，共 ${result.channelCount} 个频道')),
      );
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _requireFilePath() {
    final path = _pickedFilePath;
    if (path == null) throw StateError('请先选择文件');
    return path;
  }
}
