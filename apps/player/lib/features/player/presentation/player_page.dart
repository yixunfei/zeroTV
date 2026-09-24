import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';

/// Fullscreen player page for a single channel (single-stream playback;
/// multi-source failover lands in M3).
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
  bool _showControls = true;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    // Record watch history only once playback actually starts.
    _playingSub = _player.stream.playing.listen(_recordHistoryOnce);
    unawaited(
      _player.open(
        Media(
          widget.channel.streamUrl,
          httpHeaders: widget.channel.httpHeaders,
        ),
      ),
    );
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
              controls: (state) => const SizedBox.shrink(),
            ),
            _BufferingIndicator(player: _player),
            _ErrorIndicator(player: _player),
            if (_showControls) ...[
              _TopBar(channelName: widget.channel.name),
              _BottomBar(player: _player),
            ],
          ],
        ),
      ),
    );
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
  const _ErrorIndicator({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: player.stream.error,
      builder: (context, snapshot) {
        final error = snapshot.data;
        if (error == null || error.isEmpty) return const SizedBox.shrink();
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Text(
              '播放失败：$error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.channelName});

  final String channelName;

  @override
  Widget build(BuildContext context) {
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
              tooltip: '返回',
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Text(
                channelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '直播',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.player});

  final Player player;

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
                  tooltip: playing ? '暂停' : '播放',
                  onPressed: player.playOrPause,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
