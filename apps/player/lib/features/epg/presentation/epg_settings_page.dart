import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/shared/presentation/error_localization.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final url = ref.watch(epgUrlProvider);
    final count = ref.watch(epgProgrammeCountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.epgTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.epgUrl,
              hintText: l10n.epgUrlHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.epgHelp,
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
            label: Text(_submitting ? l10n.syncing : l10n.saveAndSync),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _clear,
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.clearEpg),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_note_outlined),
            title: Text(l10n.openGuide),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('guide'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_outlined),
            title: Text(l10n.currentSource),
            subtitle: Text(url?.toString() ?? l10n.notConfigured),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l10n.programmeCount),
            subtitle: count.when(
              data: (n) => Text('$n'),
              loading: () => Text(l10n.counting),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndSync() async {
    final raw = _controller.text.trim();
    // Validate before persisting: a malformed URL must not reach the
    // settings store only to fail the sync afterwards.
    final uri = raw.isEmpty ? null : Uri.tryParse(raw);
    if (raw.isNotEmpty &&
        (uri == null || !(uri.isScheme('http') || uri.isScheme('https')))) {
      setState(() => _error = AppLocalizations.of(context).invalidHttpUrl);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final settings = ref.read(epgSettingsProvider);
      final sync = ref.read(syncEpgProvider);
      final repository = ref.read(epgRepositoryProvider);
      await settings.setUrl(raw);
      if (mounted) ref.invalidate(epgUrlProvider);
      final feed = await sync();
      if (feed == null) {
        // The URL was cleared: drop the previously stored data too,
        // not just the configuration.
        await repository.clear();
      }
      if (!mounted) return;
      ref
        ..invalidate(epgProgrammeCountProvider)
        ..invalidate(nowNextByEpgIdProvider)
        ..invalidate(epgIndexProvider)
        ..invalidate(channelGuideProvider);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = feed == null
          ? l10n.epgDisabled
          : l10n.epgSynced(feed.channels.length, feed.programmes.length);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (e) {
      if (!mounted) return;
      setState(
        () => _error = localizedErrorText(AppLocalizations.of(context), e),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _clear() async {
    final settings = ref.read(epgSettingsProvider);
    final repository = ref.read(epgRepositoryProvider);
    await settings.setUrl(null);
    await repository.clear();
    if (!mounted) return;
    ref
      ..invalidate(epgUrlProvider)
      ..invalidate(epgProgrammeCountProvider)
      ..invalidate(nowNextByEpgIdProvider)
      ..invalidate(epgIndexProvider)
      ..invalidate(channelGuideProvider);
    if (!mounted) return;
    _controller.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).epgCleared)),
    );
  }
}
