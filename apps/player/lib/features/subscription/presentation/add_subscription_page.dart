import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addSubscriptionTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<SubscriptionKind>(
              segments: [
                ButtonSegment(
                  value: SubscriptionKind.remoteUrl,
                  icon: const Icon(Icons.link),
                  label: Text(l10n.url),
                ),
                ButtonSegment(
                  value: SubscriptionKind.localFile,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.localFile),
                ),
                ButtonSegment(
                  value: SubscriptionKind.pastedText,
                  icon: const Icon(Icons.content_paste),
                  label: Text(l10n.pastedText),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.single),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                hintText: _kind == SubscriptionKind.pastedText
                    ? l10n.nameRequired
                    : l10n.nameOptional,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (_kind == SubscriptionKind.pastedText &&
                    (v == null || v.trim().isEmpty)) {
                  return l10n.pastedNameRequired;
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
              label: Text(_submitting ? l10n.syncing : l10n.addAndSync),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _kindFields() {
    final l10n = AppLocalizations.of(context);
    switch (_kind) {
      case SubscriptionKind.remoteUrl:
        return [
          TextFormField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.playlistUrl,
              hintText: l10n.playlistUrlHint,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final uri = Uri.tryParse(v?.trim() ?? '');
              if (uri == null ||
                  !(uri.isScheme('HTTP') || uri.isScheme('HTTPS'))) {
                return l10n.invalidHttpUrl;
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
            label: Text(_pickedFilePath ?? l10n.pickPlaylist),
          ),
          if (_pickedFilePath == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.noFilePicked,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ];
      case SubscriptionKind.pastedText:
        return [
          TextFormField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: l10n.m3uContent,
              hintText: l10n.m3uHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.pasteRequired;
              return null;
            },
          ),
        ];
      case SubscriptionKind.manual:
        // Unreachable today (manual subscriptions are not offered here),
        // but a build method must never throw: show the hint instead of
        // crashing the page if a future caller reaches this branch.
        return [Text(l10n.useAddChannel)];
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: AppLocalizations.of(context).pickFileDialog,
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
    final l10n = AppLocalizations.of(context);
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
          path: _requireFilePath(l10n),
        ),
        SubscriptionKind.pastedText => await add.fromText(
          name: _nameController.text,
          content: _textController.text,
        ),
        SubscriptionKind.manual => throw UnsupportedError(
          l10n.useAddChannel,
        ),
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.subscriptionAdded(result.channelCount),
          ),
        ),
      );
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _requireFilePath(AppLocalizations l10n) {
    final path = _pickedFilePath;
    if (path == null) throw StateError(l10n.pickFileFirst);
    return path;
  }
}
