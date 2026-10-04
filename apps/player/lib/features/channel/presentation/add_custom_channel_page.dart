import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/custom_channel_providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Page for adding one hand-entered channel, or (with [existing])
/// editing a previously added one.
class AddCustomChannelPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AddCustomChannelPage({super.key, this.existing});

  /// When set, the page edits this channel instead of adding a new one.
  final Channel? existing;

  @override
  ConsumerState<AddCustomChannelPage> createState() =>
      _AddCustomChannelPageState();
}

class _AddCustomChannelPageState extends ConsumerState<AddCustomChannelPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _groupController;
  late final TextEditingController _logoController;
  bool _submitting = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _urlController = TextEditingController(text: e?.streamUrl ?? '');
    _groupController = TextEditingController(text: e?.groupTitle ?? '');
    _logoController = TextEditingController(text: e?.logoUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _groupController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.editChannelTitle : l10n.addChannelTitle),
      ),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _logoController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.logoUrlLabel,
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
                  : Icon(_editing ? Icons.save_outlined : Icons.check),
              label: Text(
                _submitting
                    ? l10n.adding
                    : (_editing ? l10n.saveAction : l10n.addChannelAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final group = _groupController.text.trim();
    final logo = _logoController.text.trim();
    final existing = widget.existing;
    final channel = Channel(
      name: _nameController.text.trim(),
      streamUrl: _urlController.text.trim(),
      groupTitle: group.isEmpty ? null : group,
      logoUrl: logo.isEmpty ? null : logo,
      tvgId: existing?.tvgId,
      tvgName: existing?.tvgName,
      catchupSource: existing?.catchupSource,
      catchupDays: existing?.catchupDays,
      userAgent: existing?.userAgent,
      referrer: existing?.referrer,
    );
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (existing != null && existing.identityKey != channel.identityKey) {
        // Renaming changes the identity key: drop the old entry so no
        // orphan remains in the "my channels" list.
        await ref.read(removeCustomChannelProvider)(existing.identityKey);
      }
      await ref.read(addCustomChannelProvider)(channel);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? l10n.channelSaved : l10n.channelAdded),
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
}
