import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Settings hub: subscriptions, EPG, sync, detection, playback, theme.
class SettingsPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_play_outlined),
            title: Text(l10n.subscriptionsTile),
            subtitle: Text(l10n.subscriptionsTileHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('subscription-management'),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(l10n.epgTitle),
            subtitle: Text(l10n.epgTileHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('epg-settings'),
          ),
          ListTile(
            leading: const Icon(Icons.fiber_manual_record_outlined),
            title: Text(l10n.recordingsTile),
            subtitle: Text(l10n.recordingsTileHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('recordings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: Text(l10n.syncInterval),
            subtitle: Text(_syncLabel(l10n, settings.syncInterval)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickSyncInterval(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.network_check_outlined),
            title: Text(l10n.probeConcurrency),
            subtitle: Text(l10n.concurrencyValue(settings.probeConcurrency)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickConcurrency(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: Text(l10n.buffer),
            subtitle: Text(_bufferLabel(settings.bufferSizeBytes)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickBuffer(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.theme),
            subtitle: Text(_themeLabel(l10n, settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.language),
            subtitle: Text(_localeLabel(l10n, settings.locale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLocale(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutTile),
            subtitle: Text(l10n.aboutTagline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('about'),
          ),
        ],
      ),
    );
  }

  static String _syncLabel(AppLocalizations l10n, Duration? interval) {
    if (interval == null) return l10n.manualOnly;
    final hours = interval.inHours;
    return hours >= 1
        ? l10n.everyHours(hours)
        : l10n.everyMinutes(interval.inMinutes);
  }

  static String _bufferLabel(int bytes) {
    final mb = bytes ~/ (1024 * 1024);
    return '$mb MB';
  }

  static String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
  }

  static String _localeLabel(AppLocalizations l10n, Locale? locale) {
    return switch (locale?.languageCode) {
      'zh' => l10n.localeZh,
      'en' => l10n.localeEn,
      _ => l10n.localeSystem,
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
                title: Text(
                  option == null
                      ? AppLocalizations.of(context).manualOnly
                      : _syncLabel(AppLocalizations.of(context), option),
                ),
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
                title: Text(
                  AppLocalizations.of(context).concurrencyValue(option),
                ),
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
    final l10n = AppLocalizations.of(context);
    final options = [
      (l10n.bufferLow, 8 * 1024 * 1024),
      (l10n.bufferBalanced, 32 * 1024 * 1024),
      (l10n.bufferStable, 64 * 1024 * 1024),
      (l10n.bufferHigh, 128 * 1024 * 1024),
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
                title: Text(_themeLabel(AppLocalizations.of(context), mode)),
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

  Future<void> _pickLocale(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).locale?.languageCode;
    final l10n = AppLocalizations.of(context);
    const system = '';
    final options = <(String, String)>[
      (system, l10n.localeSystem),
      ('zh', l10n.localeZh),
      ('en', l10n.localeEn),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (code, label) in options)
              ListTile(
                title: Text(label),
                trailing: code == (current ?? system)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final locale = picked.isEmpty ? null : Locale(picked);
    await ref.read(appSettingsProvider.notifier).setLocale(locale);
  }
}
