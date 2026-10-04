import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/widgets/error_view.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/channel/presentation/channel_logo.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Favorites management page: every starred channel in one place,
/// playable on tap, removable via the star.
class FavoritesPage extends ConsumerWidget {
  /// Creates the page.
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoriteChannelsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesTitle)),
      body: switch (favorites) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_border,
                size: 72,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.emptyFavoritesTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.emptyFavoritesHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        AsyncData(:final value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (context, i) => _FavoriteTile(channel: value[i]),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          // Invalidate the underlying stream providers; the favorites
          // view itself is purely derived and would just re-read the
          // cached error.
          onRetry: () {
            ref
              ..invalidate(allChannelsProvider)
              ..invalidate(deadKeysProvider)
              ..invalidate(favoriteKeysProvider);
          },
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: ChannelLogo(logoUrl: channel.logoUrl),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        channel.groupTitle ?? l10n.ungrouped,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.star, color: Colors.amber),
        tooltip: l10n.unfavorite,
        onPressed: () => unawaited(ref.read(toggleFavoriteProvider)(channel)),
      ),
      onTap: () => context.pushNamed('player', extra: channel),
    );
  }
}
