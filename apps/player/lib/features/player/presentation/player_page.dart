import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/player/presentation/player_osd.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/application/providers.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Fullscreen player page for a single channel.
///
/// When several sources carry the same channel (same identity key), the
/// player tries them in order and automatically advances on playback
/// failure (M3 multi-source failover).
class PlayerPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const PlayerPage({required this.channel, super.key});

  /// The channel to play.
  final Channel channel;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<String> _errorSub;
  bool _showControls = true;
  bool _recorded = false;
  PlayerAspect _aspect = PlayerAspect.contain;
  double _rate = 1;
  Recording? _recording;
  RecordingHandle? _recordingHandle;
  ManageRecording? _manageRecording;

  /// Ordered sources to try, resolved once on first build.
  List<Channel> _sources = const [];
  int _sourceIndex = 0;
  bool _switching = false;

  Channel get _current =>
      _sources.isEmpty ? widget.channel : _sources[_sourceIndex];

  @override
  void initState() {
    super.initState();
    final bufferSize = ref.read(appSettingsProvider).bufferSizeBytes;
    _player = Player(
      configuration: PlayerConfiguration(bufferSize: bufferSize),
    );
    _controller = VideoController(_player);
    _playingSub = _player.stream.playing.listen(_recordHistoryOnce);
    _errorSub = _player.stream.error.listen(_onPlaybackError);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sources.isEmpty) {
      _sources = _resolveSources();
      unawaited(_openCurrent());
    }
  }

  List<Channel> _resolveSources() {
    final all = ref.read(allChannelsProvider).value ?? const <Channel>[];
    final probes = ref.read(probeResultsProvider).value ?? const {};
    return ref.read(resolveChannelSourcesProvider)(widget.channel, all, probes);
  }

  Future<void> _openCurrent() {
    return _player.open(
      Media(_current.streamUrl, httpHeaders: _current.httpHeaders),
    );
  }

  void _onPlaybackError(String error) {
    if (error.isEmpty || _switching) return;
    if (_sourceIndex >= _sources.length - 1) return; // No more fallbacks.
    unawaited(_switchToNext());
  }

  Future<void> _switchToNext() async {
    setState(() {
      _switching = true;
      _sourceIndex++;
    });
    await _openCurrent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).switchedSource(
            _sourceIndex + 1,
            _sources.length,
            _current.name,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    _switching = false;
  }

  void _recordHistoryOnce(bool playing) {
    if (!playing || _recorded) return;
    _recorded = true;
    unawaited(
      ref
          .read(watchHistoryRepositoryProvider)
          .record(
            HistoryEntry(
              channelKey: widget.channel.identityKey,
              channelName: widget.channel.name,
              watchedAt: DateTime.now(),
            ),
          ),
    );
  }

  @override
  void dispose() {
    unawaited(_playingSub.cancel());
    unawaited(_errorSub.cancel());
    final recording = _recording;
    final handle = _recordingHandle;
    final manage = _manageRecording;
    if (recording != null && handle != null && manage != null) {
      unawaited(manage.stop(recording, handle));
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: _controller,
              fit: _aspect.fit,
              controls: (state) => const SizedBox.shrink(),
            ),
            _BufferingIndicator(player: _player),
            _ErrorIndicator(
              player: _player,
              hasFallback: _sourceIndex < _sources.length - 1,
            ),
            if (_showControls) ...[
              _TopBar(channel: widget.channel, source: _current),
              _BottomBar(
                player: _player,
                aspect: _aspect,
                rate: _rate,
                recording: _recording != null,
                onAspectChanged: (a) => setState(() => _aspect = a),
                onRateChanged: _setRate,
                onToggleRecord: _toggleRecord,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setRate(double rate) async {
    await _player.setRate(rate);
    if (!mounted) return;
    setState(() => _rate = rate);
  }

  Future<void> _toggleRecord() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (_recording != null) {
      final recording = _recording!;
      final handle = _recordingHandle;
      final manage = _manageRecording;
      setState(() {
        _recording = null;
        _recordingHandle = null;
        _manageRecording = null;
      });
      if (handle != null && manage != null) {
        await manage.stop(recording, handle);
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recordingSaved)),
      );
      return;
    }
    final manage = ref.read(manageRecordingProvider);
    try {
      final result = await manage.start(_current);
      if (!mounted) {
        await result.handle.stop();
        return;
      }
      setState(() {
        _recording = result.recording;
        _recordingHandle = result.handle;
        _manageRecording = manage;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recordingStarted)),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.recordingFailed('$e')),
        ),
      );
    }
  }
}

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: true,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  const _ErrorIndicator({required this.player, required this.hasFallback});

  final Player player;
  final bool hasFallback;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: player.stream.error,
      builder: (context, snapshot) {
        final error = snapshot.data;
        if (error == null || error.isEmpty) return const SizedBox.shrink();
        if (hasFallback) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Text(
              AppLocalizations.of(context).playbackFailed(error),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.channel, required this.source});

  final Channel channel;
  final Channel source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowNext = ref.watch(epgIndexProvider).value?.forChannel(channel);
    final nowTitle = nowNext?.now?.title;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 16,
          bottom: 8,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: AppLocalizations.of(context).back,
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  if (nowTitle != null)
                    Text(
                      AppLocalizations.of(context).nowPlaying(nowTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    )
                  else if (source.streamUrl != channel.streamUrl)
                    Text(
                      AppLocalizations.of(
                        context,
                      ).backupSource(source.groupTitle ?? source.streamUrl),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AppLocalizations.of(context).live,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.player,
    required this.aspect,
    required this.rate,
    required this.recording,
    required this.onAspectChanged,
    required this.onRateChanged,
    required this.onToggleRecord,
  });

  final Player player;
  final PlayerAspect aspect;
  final double rate;
  final bool recording;
  final ValueChanged<PlayerAspect> onAspectChanged;
  final ValueChanged<double> onRateChanged;
  final VoidCallback onToggleRecord;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          left: 8,
          right: 8,
          top: 8,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            StreamBuilder<bool>(
              stream: player.stream.playing,
              initialData: true,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return IconButton(
                  iconSize: 36,
                  color: Colors.white,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  tooltip: playing
                      ? AppLocalizations.of(context).pause
                      : AppLocalizations.of(context).play,
                  onPressed: player.playOrPause,
                );
              },
            ),
            IconButton(
              color: recording ? Colors.red : Colors.white,
              icon: Icon(
                recording ? Icons.stop_circle : Icons.fiber_manual_record,
              ),
              tooltip: recording
                  ? AppLocalizations.of(context).stopRecording
                  : AppLocalizations.of(context).startRecording,
              onPressed: onToggleRecord,
            ),
            const Spacer(),
            _AudioTrackButton(player: player),
            _SubtitleTrackButton(player: player),
            _AspectButton(aspect: aspect, onChanged: onAspectChanged),
            _RateButton(rate: rate, onChanged: onRateChanged),
          ],
        ),
      ),
    );
  }
}

class _AudioTrackButton extends StatelessWidget {
  const _AudioTrackButton({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      builder: (context, tracksSnap) {
        final audio = tracksSnap.data?.audio ?? const <AudioTrack>[];
        if (audio.length <= 1) return const SizedBox.shrink();
        return StreamBuilder<Track>(
          stream: player.stream.track,
          builder: (context, trackSnap) {
            final current = trackSnap.data?.audio ?? audio.first;
            return IconButton(
              color: Colors.white,
              icon: const Icon(Icons.audiotrack),
              tooltip: AppLocalizations.of(context).audioTracks,
              onPressed: () => showTrackMenu<AudioTrack>(
                context: context,
                title: AppLocalizations.of(context).selectAudio,
                tracks: audio,
                current: current,
                labelOf: trackLabel,
                onSelected: player.setAudioTrack,
              ),
            );
          },
        );
      },
    );
  }
}

class _SubtitleTrackButton extends StatelessWidget {
  const _SubtitleTrackButton({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      builder: (context, tracksSnap) {
        final subs = tracksSnap.data?.subtitle ?? const <SubtitleTrack>[];
        if (subs.length <= 1) return const SizedBox.shrink();
        return StreamBuilder<Track>(
          stream: player.stream.track,
          builder: (context, trackSnap) {
            final current = trackSnap.data?.subtitle ?? subs.first;
            return IconButton(
              color: Colors.white,
              icon: const Icon(Icons.subtitles_outlined),
              tooltip: AppLocalizations.of(context).subtitles,
              onPressed: () => showTrackMenu<SubtitleTrack>(
                context: context,
                title: AppLocalizations.of(context).selectSubtitle,
                tracks: subs,
                current: current,
                labelOf: subtitleLabel,
                onSelected: player.setSubtitleTrack,
              ),
            );
          },
        );
      },
    );
  }
}

class _AspectButton extends StatelessWidget {
  const _AspectButton({required this.aspect, required this.onChanged});

  final PlayerAspect aspect;
  final ValueChanged<PlayerAspect> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PlayerAspect>(
      color: Colors.black87,
      tooltip: AppLocalizations.of(context).aspectRatio,
      icon: const Icon(Icons.aspect_ratio, color: Colors.white),
      onSelected: onChanged,
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
  const _RateButton({required this.rate, required this.onChanged});

  final double rate;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      color: Colors.black87,
      tooltip: AppLocalizations.of(context).playbackSpeed,
      icon: Text(
        '${rate}x',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      onSelected: onChanged,
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
