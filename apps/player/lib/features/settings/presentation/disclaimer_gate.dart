import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Shows the first-run disclaimer once, from a context under a [Navigator].
///
/// No-op when already acknowledged. The dialog is not dismissible;
/// acknowledgement is persisted and never asked again.
Future<void> maybeShowDisclaimer(BuildContext context, WidgetRef ref) async {
  if (ref.read(appSettingsProvider).disclaimerAccepted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l10n.disclaimerDialogTitle),
        content: SingleChildScrollView(child: Text(l10n.disclaimerBody)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.disclaimerAccept),
          ),
        ],
      );
    },
  );
  if (!context.mounted) return;
  await ref.read(appSettingsProvider.notifier).acceptDisclaimer();
}
