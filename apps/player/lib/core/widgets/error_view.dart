import 'package:flutter/material.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Uniform full-area error state: icon, message and a retry action,
/// used by list pages instead of bare error text.
class ErrorView extends StatelessWidget {
  /// Creates the view.
  const ErrorView({required this.error, required this.onRetry, super.key});

  /// The failure to display.
  final Object error;

  /// Invoked when the user asks to retry the failed load.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(l10n.loadFailed('$error'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
