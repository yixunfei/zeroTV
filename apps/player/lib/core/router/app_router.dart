import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/presentation/add_custom_channel_page.dart';
import 'package:zerotv_player/features/channel/presentation/channel_list_page.dart';
import 'package:zerotv_player/features/channel/presentation/dead_channels_page.dart';
import 'package:zerotv_player/features/channel/presentation/favorites_page.dart';
import 'package:zerotv_player/features/channel/presentation/history_page.dart';
import 'package:zerotv_player/features/epg/presentation/epg_guide_page.dart';
import 'package:zerotv_player/features/epg/presentation/epg_settings_page.dart';
import 'package:zerotv_player/features/player/presentation/player_page.dart';
import 'package:zerotv_player/features/recording/presentation/recordings_page.dart';
import 'package:zerotv_player/features/settings/presentation/about_page.dart';
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
        path: '/settings/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/settings/subscriptions',
        name: 'subscription-management',
        builder: (context, state) => const SubscriptionsPage(),
      ),
      GoRoute(
        path: '/settings/epg',
        name: 'epg-settings',
        builder: (context, state) => const EpgSettingsPage(),
      ),
      GoRoute(
        path: '/recordings',
        name: 'recordings',
        builder: (context, state) => const RecordingsPage(),
      ),
      GoRoute(
        path: '/settings/dead-channels',
        name: 'dead-channels',
        builder: (context, state) => const DeadChannelsPage(),
      ),
      GoRoute(
        path: '/add-subscription',
        name: 'add-subscription',
        builder: (context, state) => const AddSubscriptionPage(),
      ),
      GoRoute(
        path: '/add-channel',
        name: 'add-channel',
        builder: (context, state) => const AddCustomChannelPage(),
      ),
      GoRoute(
        path: '/edit-channel',
        name: 'edit-channel',
        builder: (context, state) {
          final channel = state.extra;
          if (channel is! Channel) return const ChannelListPage();
          return AddCustomChannelPage(existing: channel);
        },
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: '/guide',
        name: 'guide',
        builder: (context, state) => const EpgGuidePage(),
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
