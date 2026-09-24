import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotv_player/core/router/app_router.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/core/theme/app_theme.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Root application widget.
class ZeroTvApp extends ConsumerWidget {
  /// Creates the app.
  const ZeroTvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsProvider);
    final themeMode = settings.themeMode;
    final locale = settings.locale;
    return MaterialApp.router(
      title: 'zeroTV',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
