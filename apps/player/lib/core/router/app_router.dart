import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/presentation/channel_list_page.dart';
import 'package:zerotv_player/features/player/presentation/player_page.dart';
import 'package:zerotv_player/features/settings/presentation/settings_page.dart';
import 'package:zerotv_player/features/subscription/presentation/add_subscription_page.dart';
import 'package:zerotv_player/features/subscription/presentation/subscriptions_page.dart';

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
      GoRoute(
        path: '/settings/subscriptions',
        name: 'subscription-management',
        builder: (context, state) => const SubscriptionsPage(),
      ),
      GoRoute(
        path: '/add-subscription',
        name: 'add-subscription',
        builder: (context, state) => const AddSubscriptionPage(),
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        builder: (context, state) {
          final channel = state.extra;
          if (channel is! Channel) {
            // Defensive: direct URL entry has no channel; bounce home.
            return const ChannelListPage();
          }
          return PlayerPage(channel: channel);
        },
      ),
    ],
  );
});
