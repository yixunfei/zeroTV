import 'package:flutter/material.dart';
import 'package:zerotv_player/features/player/presentation/player_chrome.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Responsive channel information and navigation, independent of playback.
class PlayerTopControls extends StatelessWidget {
  /// Creates the channel toolbar.
  const PlayerTopControls({
    required this.title,
    required this.inCatchup,
    required this.isLandscape,
    required this.onBack,
    required this.onReturnToLive,
    required this.onToggleOrientation,
    required this.onToggleLock,
    required this.onMenuVisibilityChanged,
    this.subtitle,
    this.onShowSources,
    this.onShowCatchup,
    this.isLocal = false,
    super.key,
  });

  /// Channel name.
  final String title;

  /// Programme or backup-source description.
  final String? subtitle;

  /// Whether a past programme is playing.
  final bool inCatchup;

  /// Whether the viewport is currently landscape.
  final bool isLandscape;

  /// Local recordings do not display a live badge.
  final bool isLocal;

  /// Leaves playback.
  final VoidCallback onBack;

  /// Resumes live playback.
  final VoidCallback onReturnToLive;

  /// Toggles device orientation.
  final VoidCallback onToggleOrientation;

  /// Locks playback controls.
  final VoidCallback onToggleLock;

  /// Keeps the controls visible while a menu is open.
  final ValueChanged<bool> onMenuVisibilityChanged;

  /// Opens source selection when available.
  final VoidCallback? onShowSources;

  /// Opens the current channel's programme history when available.
  final VoidCallback? onShowCatchup;

  @override
  Widget build(BuildContext context) => PlayerControlSurface(
    top: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 640 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        final l10n = AppLocalizations.of(context);
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: l10n.back,
              onPressed: onBack,
            ),
            const SizedBox(width: 6),
            Expanded(child: _information(context, compact: compact)),
            if (!compact && !isLocal) ...[
              const SizedBox(width: 12),
              _liveBadge(context),
            ],
            const SizedBox(width: 4),
            if (compact) _overflow(context) else ..._actions(context),
          ],
        );
      },
    ),
  );

  Widget _information(BuildContext context, {required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      if (subtitle != null || (compact && !isLocal))
        Text(
          _subtitle(context, compact),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
    ],
  );

  String _subtitle(BuildContext context, bool compact) {
    if (!compact || isLocal) return subtitle!;
    final l10n = AppLocalizations.of(context);
    final status = inCatchup ? l10n.catchup : l10n.live;
    return [status, ?subtitle].join(' · ');
  }

  Widget _liveBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (inCatchup) {
      return TextButton.icon(
        onPressed: onReturnToLive,
        icon: const Icon(Icons.live_tv_rounded, size: 16),
        label: Text(l10n.backToLive),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffd83b45).withValues(alpha: .18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '● ${l10n.live}',
          style: const TextStyle(color: Color(0xffff8b93), fontSize: 12),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      if (onShowCatchup != null)
        IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: l10n.catchup,
          onPressed: onShowCatchup,
        ),
      if (onShowSources != null)
        IconButton(
          icon: const Icon(Icons.playlist_play_rounded),
          tooltip: l10n.selectSource,
          onPressed: onShowSources,
        ),
      IconButton(
        icon: Icon(
          isLandscape
              ? Icons.stay_current_portrait_rounded
              : Icons.stay_current_landscape_rounded,
        ),
        tooltip: isLandscape ? l10n.exitLandscape : l10n.enterLandscape,
        onPressed: onToggleOrientation,
      ),
      IconButton(
        icon: const Icon(Icons.lock_open_rounded),
        tooltip: l10n.lockScreen,
        onPressed: onToggleLock,
      ),
    ];
  }

  Widget _overflow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = <(IconData, String, VoidCallback)>[
      if (inCatchup) (Icons.live_tv, l10n.backToLive, onReturnToLive),
      if (onShowCatchup != null)
        (Icons.history_rounded, l10n.catchup, onShowCatchup!),
      if (onShowSources != null)
        (Icons.playlist_play, l10n.selectSource, onShowSources!),
      (
        Icons.screen_rotation,
        isLandscape ? l10n.exitLandscape : l10n.enterLandscape,
        onToggleOrientation,
      ),
      (Icons.lock_open, l10n.lockScreen, onToggleLock),
    ];
    return PopupMenuButton<int>(
      key: const ValueKey('player-navigation-menu'),
      tooltip: l10n.menuMore,
      icon: const Icon(Icons.more_horiz_rounded),
      onOpened: () => onMenuVisibilityChanged(true),
      onCanceled: () => onMenuVisibilityChanged(false),
      onSelected: (index) {
        onMenuVisibilityChanged(false);
        actions[index].$3();
      },
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(actions[i].$1, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(actions[i].$2)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Adaptive transport layout. Playback streams are owned by the page.
class PlayerTransportControls extends StatelessWidget {
  /// Creates the lower toolbar with compact and expanded settings.
  const PlayerTransportControls({
    required this.playButton,
    required this.recordButton,
    required this.volumeControl,
    required this.secondaryControls,
    required this.moreButton,
    this.progress,
    super.key,
  });

  /// Primary playback action.
  final Widget playButton;

  /// Recording action, including disabled and stop states.
  final Widget recordButton;

  /// Volume slider.
  final Widget volumeControl;

  /// Audio, subtitle, aspect ratio and speed controls for wide viewports.
  final List<Widget> secondaryControls;

  /// Compact settings entry point.
  final Widget moreButton;

  /// Current programme timeline when playing live.
  final Widget? progress;

  @override
  Widget build(BuildContext context) => PlayerControlSurface(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 720 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?progress,
            Row(
              children: [
                playButton,
                recordButton,
                const SizedBox(width: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: volumeControl,
                    ),
                  ),
                ),
                if (compact) moreButton else ...secondaryControls,
              ],
            ),
          ],
        );
      },
    ),
  );
}
