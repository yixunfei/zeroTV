import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/custom_channel_providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Page for adding one hand-entered channel to the "my channels" list.
class AddCustomChannelPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AddCustomChannelPage({super.key});

  @override
  ConsumerState<AddCustomChannelPage> createState() =>
      _AddCustomChannelPageState();
}

class _AddCustomChannelPageState extends ConsumerState<AddCustomChannelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _groupController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addChannelTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.channelName,
                hintText: l10n.channelNameHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.channelNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.streamUrl,
                hintText: l10n.streamUrlHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final uri = Uri.tryParse(v?.trim() ?? '');
                if (uri == null || !uri.hasScheme) {
                  return l10n.streamUrlInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupController,
              decoration: InputDecoration(
                labelText: l10n.group,
                hintText: l10n.groupHint,
                border: const OutlineInputBorder(),
              ),
            ),
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
                  : const Icon(Icons.check),
              label: Text(_submitting ? l10n.adding : l10n.addChannelAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final group = _groupController.text.trim();
    final channel = Channel(
      name: _nameController.text.trim(),
      streamUrl: _urlController.text.trim(),
      groupTitle: group.isEmpty ? null : group,
    );
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(addCustomChannelProvider)(channel);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).channelAdded)),
      );
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
