import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotv_player/features/channel/presentation/channel_list_page.dart';
import 'package:zerotv_player/features/settings/presentation/settings_page.dart';

/// Provides the app-wide router.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'channels',
        builder: (context, state) => const ChannelListPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
