import 'package:flutter/material.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// About screen: version, license, and the standing disclaimer.
class AboutPage extends StatelessWidget {
  /// Creates the page.
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.appTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(l10n.aboutTagline, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text(l10n.disclaimerHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.disclaimerBody),
          const SizedBox(height: 24),
          Text(l10n.licenseHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.licenseBody),
        ],
      ),
    );
  }
}
