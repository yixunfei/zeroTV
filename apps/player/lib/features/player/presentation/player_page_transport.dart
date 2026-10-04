part of 'player_page.dart';

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.channel,
    required this.source,
    required this.isLandscape,
    required this.inCatchup,
    required this.onReturnToLive,
    required this.onToggleOrientation,
    required this.onToggleLock,
    required this.onShowSources,
    required this.onShowCatchup,
    required this.onMenuVisibilityChanged,
    this.catchupTitle,
  });

  final Channel channel;
  final Channel source;
  final bool isLandscape;
  final bool inCatchup;
  final String? catchupTitle;
  final VoidCallback onReturnToLive;
  final VoidCallback onToggleOrientation;
  final VoidCallback onToggleLock;
  final VoidCallback? onShowSources;
  final VoidCallback? onShowCatchup;
  final ValueChanged<bool> onMenuVisibilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(epgIndexProvider).value?.forChannel(channel)?.now;
    final subtitle = inCatchup ? catchupTitle : now?.title;
    return PlayerTopControls(
      title: channel.name,
      subtitle: subtitle != null
          ? l10n.nowPlaying(subtitle)
          : source.streamUrl != channel.streamUrl
          ? l10n.backupSource(source.groupTitle ?? source.streamUrl)
          : null,
      inCatchup: inCatchup,
      isLocal: Uri.tryParse(channel.streamUrl)?.scheme == 'file',
      isLandscape: isLandscape,
      onBack: () => context.pop(),
      onReturnToLive: onReturnToLive,
      onToggleOrientation: onToggleOrientation,
      onToggleLock: onToggleLock,
      onShowSources: onShowSources,
      onShowCatchup: onShowCatchup,
      onMenuVisibilityChanged: onMenuVisibilityChanged,
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.player,
    required this.channel,
    required this.aspect,
    required this.rate,
    required this.recording,
    required this.inCatchup,
    required this.onAspectChanged,
    required this.onRateChanged,
    required this.onToggleRecord,
    required this.recordSupported,
    required this.onInteraction,
    required this.onMenuVisibilityChanged,
  });

  final Player player;
  final Channel channel;
  final PlayerAspect aspect;
  final double rate;
  final bool recording;
  final bool inCatchup;
  final bool recordSupported;
  final ValueChanged<PlayerAspect> onAspectChanged;
  final ValueChanged<double> onRateChanged;
  final VoidCallback? onToggleRecord;
  final VoidCallback onInteraction;
  final ValueChanged<bool> onMenuVisibilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(epgIndexProvider).value?.forChannel(channel)?.now;
    final l10n = AppLocalizations.of(context);
    return PlayerTransportControls(
      progress: !inCatchup && program != null
          ? _ProgramProgress(program: program)
          : null,
      playButton: _playButton(context),
      recordButton: _PlayerIconButton(
        icon: recording ? Icons.stop_circle : Icons.fiber_manual_record,
        color: recording ? const Color(0xffef5360) : Colors.white,
        tooltip: recording
            ? l10n.stopRecording
            : recordSupported
            ? l10n.startRecording
            : l10n.recordUnsupported,
        onPressed: onToggleRecord,
      ),
      volumeControl: _VolumeControl(
        player: player,
        onInteraction: onInteraction,
      ),
      secondaryControls: _settings(),
      moreButton: _MoreControlsButton(
        player: player,
        aspect: aspect,
        rate: rate,
        onAspectChanged: onAspectChanged,
        onRateChanged: onRateChanged,
        onMenuVisibilityChanged: onMenuVisibilityChanged,
      ),
    );
  }

  Widget _playButton(BuildContext context) => StreamBuilder<bool>(
    stream: player.stream.playing,
    initialData: player.state.playing,
    builder: (context, snapshot) {
      final playing = snapshot.data ?? false;
      final l10n = AppLocalizations.of(context);
      return IconButton.filled(
        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        tooltip: playing ? l10n.pause : l10n.play,
        onPressed: () {
          unawaited(player.playOrPause());
          onInteraction();
        },
      );
    },
  );

  List<Widget> _settings() => [
    _AudioTrackButton(
      player: player,
      onMenuVisibilityChanged: onMenuVisibilityChanged,
    ),
    _SubtitleTrackButton(
      player: player,
      onMenuVisibilityChanged: onMenuVisibilityChanged,
    ),
    _AspectButton(
      aspect: aspect,
      onChanged: onAspectChanged,
      onMenuVisibilityChanged: onMenuVisibilityChanged,
    ),
    _RateButton(
      rate: rate,
      onChanged: onRateChanged,
      onMenuVisibilityChanged: onMenuVisibilityChanged,
    ),
  ];
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.white,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      tooltip: tooltip,
      disabledColor: Colors.white30,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.player, required this.onInteraction});

  final Player player;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.volume_up_outlined, color: Colors.white70, size: 19),
        Expanded(
          child: StreamBuilder<double>(
            stream: player.stream.volume,
            initialData: player.state.volume,
            builder: (context, snapshot) {
              final volume = (snapshot.data ?? 100).clamp(0, 100);
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: volume.toDouble(),
                  max: 100,
                  onChanged: (value) {
                    unawaited(player.setVolume(value));
                    onInteraction();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MoreControlsButton extends StatelessWidget {
  const _MoreControlsButton({
    required this.player,
    required this.aspect,
    required this.rate,
    required this.onAspectChanged,
    required this.onRateChanged,
    required this.onMenuVisibilityChanged,
  });

  final Player player;
  final PlayerAspect aspect;
  final double rate;
  final ValueChanged<PlayerAspect> onAspectChanged;
  final ValueChanged<double> onRateChanged;
  final ValueChanged<bool> onMenuVisibilityChanged;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('player-settings-menu'),
    icon: const Icon(Icons.tune_rounded),
    tooltip: AppLocalizations.of(context).menuMore,
    onPressed: () => _show(context),
  );

  Future<void> _show(BuildContext context) async {
    var selectedAspect = aspect;
    var selectedRate = rate;
    onMenuVisibilityChanged(true);
    try {
      await showPlayerSheet<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setMenuState) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  AppLocalizations.of(context).settings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _AudioTrackButton(
                player: player,
                showLabel: true,
                onMenuVisibilityChanged: onMenuVisibilityChanged,
              ),
              _SubtitleTrackButton(
                player: player,
                showLabel: true,
                onMenuVisibilityChanged: onMenuVisibilityChanged,
              ),
              _SettingRow(
                title: AppLocalizations.of(context).aspectRatio,
                child: _AspectButton(
                  aspect: selectedAspect,
                  onMenuVisibilityChanged: onMenuVisibilityChanged,
                  onChanged: (value) {
                    setMenuState(() => selectedAspect = value);
                    onAspectChanged(value);
                  },
                ),
              ),
              _SettingRow(
                title: AppLocalizations.of(context).playbackSpeed,
                child: _RateButton(
                  rate: selectedRate,
                  onMenuVisibilityChanged: onMenuVisibilityChanged,
                  onChanged: (value) {
                    setMenuState(() => selectedRate = value);
                    onRateChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      onMenuVisibilityChanged(false);
    }
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(title)),
        child,
      ],
    ),
  );
}

class _AudioTrackButton extends StatelessWidget {
  const _AudioTrackButton({
    required this.player,
    required this.onMenuVisibilityChanged,
    this.showLabel = false,
  });
  final Player player;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => StreamBuilder<Tracks>(
    stream: player.stream.tracks,
    initialData: player.state.tracks,
    builder: (context, snapshot) {
      final tracks = snapshot.data?.audio ?? const <AudioTrack>[];
      return StreamBuilder<Track>(
        stream: player.stream.track,
        initialData: player.state.track,
        builder: (context, snapshot) {
          final current = snapshot.data?.audio;
          final enabled = tracks.length > 1 && current != null;
          final l10n = AppLocalizations.of(context);
          final onTap = enabled ? () => _show(context, tracks, current) : null;
          if (showLabel) {
            return ListTile(
              enabled: enabled,
              leading: const Icon(Icons.audiotrack),
              title: Text(l10n.audioTracks),
              subtitle: current == null
                  ? null
                  : Text(
                      trackLabel(current),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: onTap,
            );
          }
          return IconButton(
            icon: const Icon(Icons.audiotrack),
            tooltip: l10n.audioTracks,
            onPressed: onTap,
          );
        },
      );
    },
  );

  Future<void> _show(
    BuildContext context,
    List<AudioTrack> tracks,
    AudioTrack current,
  ) async {
    onMenuVisibilityChanged(true);
    try {
      await showTrackMenu<AudioTrack>(
        context: context,
        title: AppLocalizations.of(context).selectAudio,
        tracks: tracks,
        current: current,
        idOf: (track) => track.id,
        labelOf: trackLabel,
        onSelected: player.setAudioTrack,
      );
    } finally {
      onMenuVisibilityChanged(false);
    }
  }
}

class _SubtitleTrackButton extends StatelessWidget {
  const _SubtitleTrackButton({
    required this.player,
    required this.onMenuVisibilityChanged,
    this.showLabel = false,
  });
  final Player player;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => StreamBuilder<Tracks>(
    stream: player.stream.tracks,
    initialData: player.state.tracks,
    builder: (context, snapshot) {
      final tracks = snapshot.data?.subtitle ?? const <SubtitleTrack>[];
      return StreamBuilder<Track>(
        stream: player.stream.track,
        initialData: player.state.track,
        builder: (context, snapshot) {
          final current = snapshot.data?.subtitle;
          final enabled = tracks.length > 1 && current != null;
          final l10n = AppLocalizations.of(context);
          final onTap = enabled ? () => _show(context, tracks, current) : null;
          if (showLabel) {
            return ListTile(
              enabled: enabled,
              leading: const Icon(Icons.subtitles_outlined),
              title: Text(l10n.subtitles),
              subtitle: current == null
                  ? null
                  : Text(
                      subtitleLabel(current),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: onTap,
            );
          }
          return IconButton(
            icon: const Icon(Icons.subtitles_outlined),
            tooltip: l10n.subtitles,
            onPressed: onTap,
          );
        },
      );
    },
  );

  Future<void> _show(
    BuildContext context,
    List<SubtitleTrack> tracks,
    SubtitleTrack current,
  ) async {
    onMenuVisibilityChanged(true);
    try {
      await showTrackMenu<SubtitleTrack>(
        context: context,
        title: AppLocalizations.of(context).selectSubtitle,
        tracks: tracks,
        current: current,
        idOf: (track) => track.id,
        labelOf: subtitleLabel,
        onSelected: player.setSubtitleTrack,
      );
    } finally {
      onMenuVisibilityChanged(false);
    }
  }
}

class _AspectButton extends StatelessWidget {
  const _AspectButton({
    required this.aspect,
    required this.onChanged,
    required this.onMenuVisibilityChanged,
  });

  final PlayerAspect aspect;
  final ValueChanged<PlayerAspect> onChanged;
  final ValueChanged<bool> onMenuVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PlayerAspect>(
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: AppLocalizations.of(context).aspectRatio,
      icon: const Icon(Icons.aspect_ratio, color: Colors.white),
      onOpened: () => onMenuVisibilityChanged(true),
      onCanceled: () => onMenuVisibilityChanged(false),
      onSelected: (value) {
        onMenuVisibilityChanged(false);
        onChanged(value);
      },
      itemBuilder: (context) => [
        for (final a in PlayerAspect.values)
          PopupMenuItem(
            value: a,
            child: Row(
              children: [
                if (a == aspect)
                  const Icon(Icons.check, size: 18, color: Colors.white)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  _aspectLabel(AppLocalizations.of(context), a),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.rate,
    required this.onChanged,
    required this.onMenuVisibilityChanged,
  });

  final double rate;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onMenuVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: AppLocalizations.of(context).playbackSpeed,
      icon: Text(
        '${rate}x',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      onOpened: () => onMenuVisibilityChanged(true),
      onCanceled: () => onMenuVisibilityChanged(false),
      onSelected: (value) {
        onMenuVisibilityChanged(false);
        onChanged(value);
      },
      itemBuilder: (context) => [
        for (final r in playerRatePresets)
          PopupMenuItem(
            value: r,
            child: Row(
              children: [
                if (r == rate)
                  const Icon(Icons.check, size: 18, color: Colors.white)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text('${r}x', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }
}

String _aspectLabel(AppLocalizations l10n, PlayerAspect aspect) {
  return switch (aspect) {
    PlayerAspect.contain => l10n.aspectContain,
    PlayerAspect.cover => l10n.aspectCover,
    PlayerAspect.fill => l10n.aspectFill,
    PlayerAspect.fitWidth => l10n.aspectFitWidth,
    PlayerAspect.fitHeight => l10n.aspectFitHeight,
  };
}

/// A slim progress bar over the currently airing programme's time
/// range, rebuilt once a minute while visible.
class _ProgramProgress extends StatefulWidget {
  const _ProgramProgress({required this.program});

  final EpgProgram program;

  @override
  State<_ProgramProgress> createState() => _ProgramProgressState();
}

class _ProgramProgressState extends State<_ProgramProgress> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final now = DateTime.now();
    final total = program.stop.difference(program.start).inSeconds;
    final elapsed = now.difference(program.start).inSeconds;
    final value = total <= 0 ? 0.0 : (elapsed / total).clamp(0.0, 1.0);
    final start = TimeOfDay.fromDateTime(program.start.toLocal());
    final stop = TimeOfDay.fromDateTime(program.stop.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
      child: Row(
        children: [
          Text(
            start.format(context),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xff70c5ff)),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            stop.format(context),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
