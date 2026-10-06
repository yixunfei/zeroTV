import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zerotv_player/core/network/overseas_network.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/player/application/playback_session.dart';
import 'package:zerotv_player/features/player/presentation/player_chrome.dart';
import 'package:zerotv_player/features/player/presentation/player_controls.dart';
import 'package:zerotv_player/features/player/presentation/player_history_panel.dart';
import 'package:zerotv_player/features/player/presentation/player_osd.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/application/providers.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';
import 'package:zerotv_player/features/recording/domain/segmented_playlist.dart';
import 'package:zerotv_player/features/shared/presentation/error_localization.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

part 'player_page_panels.dart';
part 'player_page_transport.dart';

/// Fullscreen player page for a single channel.
///
/// When several sources carry the same channel (same identity key), the
/// player tries them in order and automatically advances on playback
/// failure (M3 multi-source failover). The OSD offers play/pause, a
/// volume slider, aspect ratio, speed, source switching, catchup
/// playback and screen lock; a tap toggles the controls, which also
/// auto-hide after a few seconds.
class PlayerPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const PlayerPage({required this.channel, super.key});

  /// The channel to play.
  final Channel channel;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _controlsTimeout = Duration(seconds: 4);
  static const _doubleTapSeek = Duration(seconds: 10);

  late final Player _player;
  late final VideoController _controller;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<String> _errorSub;
  bool _showControls = true;
  bool _locked = false;
  bool _recorded = false;
  bool _inCatchup = false;
  bool _showHistoryPanel = false;
  EpgProgram? _catchupProgramme;
  int _openMenus = 0;
  Future<List<EpgProgram>>? _historyFuture;
  bool _sessionInit = false;
  PlayerAspect _aspect = PlayerAspect.contain;
  double _rate = 1;
  Recording? _recording;
  RecordingHandle? _recordingHandle;
  ManageRecording? _manageRecording;

  PlaybackSession? _session;
  bool _recordingBusy = false;
  Timer? _hideTimer;
  Timer? _seekIndicatorTimer;
  Duration? _seekDelta;

  Channel get _current => _session?.current ?? widget.channel;
  bool get _isLocal => Uri.tryParse(widget.channel.streamUrl)?.scheme == 'file';

  /// HLS/DASH playlists cannot be captured byte-stream style; the same
  /// predicate the recorder enforces (see [isSegmentedPlaylistUrl]).
  bool get _recordUnsupported =>
      _isLocal || _inCatchup || isSegmentedPlaylistUrl(_current.streamUrl);

  /// Whether the record button should be enabled.
  bool get _canRecord => !_recordUnsupported;

  @override
  void initState() {
    super.initState();
    final bufferSize = ref.read(appSettingsProvider).bufferSizeBytes;
    _player = Player(
      configuration: PlayerConfiguration(bufferSize: bufferSize),
    );
    _controller = VideoController(_player);
    _playingSub = _player.stream.playing.listen(_recordHistoryOnce);
    _errorSub = _player.stream.error.listen(
      (error) => _session?.onError(error),
    );
    _scheduleHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionInit) return;
    _sessionInit = true;
    unawaited(_initSession());
  }

  Future<void> _initSession() async {
    // The channel table stream emits asynchronously; reading `.value` here
    // would race the first emission and silently drop all backup sources.
    var sources = [widget.channel];
    if (!_isLocal) {
      try {
        final all = await ref.read(allChannelsProvider.future);
        if (!mounted) return;
        final probes = await ref.read(probeResultsProvider.future);
        if (!mounted) return;
        sources = ref.read(resolveChannelSourcesProvider)(
          widget.channel,
          all,
          probes,
        );
      } on Object {
        // Failover resolution is best-effort; fall back to the single
        // source the user tapped.
      }
    }
    if (!mounted) return;
    _session = PlaybackSession(
      sources: sources,
      open: (channel) => _player.open(
        Media(channel.streamUrl, httpHeaders: channel.httpHeaders),
      ),
    )..addListener(_onSessionChanged);
    unawaited(_session!.start());
    unawaited(_showOverseasNetworkHintIfNeeded());
  }

  Future<void> _showOverseasNetworkHintIfNeeded() async {
    if (!needsOverseasNetworkHint(widget.channel) || !mounted) return;
    if (!ref.read(appSettingsProvider).showOverseasNetworkHint) return;
    var doNotShowAgain = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).overseasNetworkTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context).overseasNetworkBody),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: doNotShowAgain,
                onChanged: (value) =>
                    setDialogState(() => doNotShowAgain = value ?? false),
                title: Text(
                  AppLocalizations.of(context).overseasNetworkDontShow,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).overseasNetworkLater),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).overseasNetworkContinue),
            ),
          ],
        ),
      ),
    );
    if (doNotShowAgain && mounted) {
      await ref
          .read(appSettingsProvider.notifier)
          .setOverseasNetworkHint(enabled: false);
    }
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _recordHistoryOnce(bool playing) {
    if (playing) _session?.onPlaying();
    if (!mounted || !playing || _recorded || _isLocal) return;
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
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _session?.dispose();
    unawaited(_playingSub.cancel());
    unawaited(_errorSub.cancel());
    final recording = _recording;
    final handle = _recordingHandle;
    final manage = _manageRecording;
    if (recording != null && handle != null && manage != null) {
      manage.stop(recording, handle).ignore();
    }
    unawaited(_restoreOrientation());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _restoreOrientation() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_showHistoryPanel || _openMenus > 0 || _locked) return;
    _hideTimer = Timer(_controlsTimeout, () {
      if (mounted && _showControls) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _onDoubleTap(TapDownDetails details, Size size) {
    if (_locked) return;
    final isLeft = details.globalPosition.dx < size.width / 2;
    final delta = isLeft ? -_doubleTapSeek : _doubleTapSeek;
    unawaited(_seekBy(delta));
    setState(() => _seekDelta = delta);
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekDelta = null);
    });
  }

  Future<void> _seekBy(Duration delta) async {
    final position = _player.state.position;
    var target = position + delta;
    if (target < Duration.zero) target = Duration.zero;
    await _player.seek(target);
  }

  void _onInteraction() {
    if (_showControls) _scheduleHide();
  }

  void _onMenuVisibilityChanged(bool visible) {
    if (!mounted) return;
    _openMenus = visible ? _openMenus + 1 : (_openMenus - 1).clamp(0, 100);
    _hideTimer?.cancel();
    if (_openMenus == 0 && _showControls) _scheduleHide();
  }

  Future<void> _toggleLock() async {
    setState(() {
      _locked = !_locked;
      _showControls = !_locked;
    });
    if (!_locked) _scheduleHide();
  }

  Future<void> _enterLandscape() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: const [],
    );
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitLandscape() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations(const []);
  }

  bool get _isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_showHistoryPanel,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) {
        unawaited(_restoreOrientation());
      } else if (_showHistoryPanel) {
        _closeHistoryPanel();
      }
    },
    child: Theme(
      data: playerTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) => _buildVideo(
            Size(constraints.maxWidth, constraints.maxHeight),
          ),
        ),
      ),
    ),
  );

  Widget _buildVideo(Size size) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _locked || _showHistoryPanel ? null : _onTap,
    onDoubleTapDown: _locked || _showHistoryPanel
        ? null
        : (details) => _onDoubleTap(details, size),
    onDoubleTap: _locked || _showHistoryPanel ? null : () {},
    child: Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: _controller,
          fit: _aspect.fit,
          controls: (state) => const SizedBox.shrink(),
        ),
        _buildPlaybackFeedback(),
        if (_seekDelta case final Duration delta) _buildSeekFeedback(delta),
        _buildControlOverlay(),
        if (_showHistoryPanel) ..._buildHistoryOverlay(size),
      ],
    ),
  );

  Widget _buildPlaybackFeedback() {
    final session = _session;
    if (session?.error case final String error) {
      return _PlaybackErrorPanel(
        error: error,
        hasMultipleSources: (session?.sources.length ?? 0) > 1,
        onRetry: () {
          _exitCatchup();
          session?.retry();
        },
        onShowSources: _showSourceSheet,
      );
    }
    if (session != null && session.opening && session.index > 0) {
      return _SwitchingSourceHint(session: session);
    }
    return _BufferingIndicator(player: _player);
  }

  Widget _buildSeekFeedback(Duration delta) => IgnorePointer(
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xff101318).withValues(alpha: .85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          '${delta.isNegative ? '-' : '+'}${delta.inSeconds.abs()}s',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    ),
  );

  Widget _buildControlOverlay() {
    if (_locked) {
      return Positioned(
        top: 0,
        left: 0,
        child: SafeArea(
          minimum: const EdgeInsets.all(12),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.lock_rounded),
            tooltip: AppLocalizations.of(context).unlockScreen,
            onPressed: _toggleLock,
          ),
        ),
      );
    }
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showControls,
        child: ExcludeSemantics(
          excluding: !_showControls,
          child: AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _controlRegion(_buildTopBar()),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _controlRegion(_buildBottomBar()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlRegion(Widget child) => Listener(
    onPointerDown: (_) => _hideTimer?.cancel(),
    onPointerUp: (_) => _onInteraction(),
    onPointerCancel: (_) => _onInteraction(),
    child: GestureDetector(
      onTap: _onInteraction,
      onDoubleTap: () {},
      child: child,
    ),
  );

  Widget _buildTopBar() => _TopBar(
    channel: widget.channel,
    source: _current,
    isLandscape: _isLandscape,
    inCatchup: _inCatchup,
    catchupTitle: _catchupProgramme?.title,
    onReturnToLive: _returnToLive,
    onToggleOrientation: () => unawaited(
      _isLandscape ? _exitLandscape() : _enterLandscape(),
    ),
    onToggleLock: _toggleLock,
    onShowSources: (_session?.sources.length ?? 0) > 1
        ? _showSourceSheet
        : null,
    onShowCatchup: widget.channel.catchupSource != null
        ? _toggleHistoryPanel
        : null,
    onMenuVisibilityChanged: _onMenuVisibilityChanged,
  );

  Widget _buildBottomBar() => _BottomBar(
    player: _player,
    channel: widget.channel,
    aspect: _aspect,
    rate: _rate,
    recording: _recording != null,
    inCatchup: _inCatchup,
    onAspectChanged: (a) => setState(() => _aspect = a),
    onRateChanged: _setRate,
    // An active recording must remain stoppable after a source change.
    onToggleRecord: _recordingBusy || (_recording == null && !_canRecord)
        ? null
        : _toggleRecord,
    recordSupported: _canRecord,
    onInteraction: _onInteraction,
    onMenuVisibilityChanged: _onMenuVisibilityChanged,
  );

  List<Widget> _buildHistoryOverlay(Size size) => [
    Positioned.fill(
      child: ModalBarrier(
        color: Colors.black54,
        onDismiss: _closeHistoryPanel,
        semanticsLabel: AppLocalizations.of(context).close,
      ),
    ),
    Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: size.width < 480 ? size.width * .9 : 360,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(begin: const Offset(1, 0), end: Offset.zero),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, offset, child) => FractionalTranslation(
          translation: offset,
          child: child,
        ),
        child: PlayerHistoryPanel(
          programmes: _historyFuture,
          selected: _catchupProgramme,
          onClose: _closeHistoryPanel,
          onSelected: _selectCatchup,
        ),
      ),
    ),
  ];

  Future<void> _selectCatchup(EpgProgram programme) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    _closeHistoryPanel();
    try {
      await _openCatchup(widget.channel, programme);
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.playbackFailed('$error'))),
      );
    }
  }

  Future<void> _showSourceSheet() async {
    _onMenuVisibilityChanged(true);
    try {
      await _selectSource();
    } finally {
      _onMenuVisibilityChanged(false);
    }
  }

  Future<void> _selectSource() async {
    final session = _session;
    if (session == null) return;
    final l10n = AppLocalizations.of(context);
    final picked = await showPlayerSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Text(
                l10n.selectSource,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (var i = 0; i < session.sources.length; i++)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(
                  session.sources[i].groupTitle ??
                      AppLocalizations.of(context).sourceNumber(i + 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  session.sources[i].streamUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: i == session.index
                    ? const Icon(Icons.check, color: Color(0xff70c5ff))
                    : null,
                onTap: () => Navigator.of(context).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      _exitCatchup();
      session.switchTo(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.switchedSource(
                picked + 1,
                session.sources.length,
                session.sources[picked].groupTitle ??
                    l10n.sourceNumber(picked + 1),
              ),
            ),
          ),
        );
      }
    }
  }

  void _closeHistoryPanel() {
    setState(() => _showHistoryPanel = false);
    _scheduleHide();
  }

  void _toggleHistoryPanel() {
    if (_showHistoryPanel) {
      _closeHistoryPanel();
      return;
    }
    _hideTimer?.cancel();
    setState(() {
      _showHistoryPanel = true;
      _showControls = true;
      _historyFuture = _loadCatchupProgrammes();
    });
  }

  Future<List<EpgProgram>> _loadCatchupProgrammes() async {
    final channel = widget.channel;
    final epgId = (await ref.read(epgIndexProvider.future)).epgIdFor(channel);
    if (epgId == null) return const [];
    return ref
        .read(epgRepositoryProvider)
        .programmesFor(
          epgId,
          DateTime.now().subtract(Duration(days: channel.catchupDays ?? 3)),
          DateTime.now(),
        );
  }

  Future<void> _openCatchup(Channel channel, EpgProgram programme) async {
    final template = channel.catchupSource;
    if (template == null) return;
    final utc = programme.start.toUtc();
    final stamp = '${utc.millisecondsSinceEpoch ~/ 1000}';
    final iso = utc.toIso8601String();
    final url = template
        .replaceAll(r'${utc}', iso)
        .replaceAll('{utc}', iso)
        .replaceAll(r'${timestamp}', stamp)
        .replaceAll('{timestamp}', stamp);
    // Suspend the session's source failover: a failing catchup stream
    // must surface its error instead of kicking the user back to live.
    setState(() {
      _inCatchup = true;
      _catchupProgramme = programme;
    });
    _session?.suspendFailover();
    try {
      await _player.open(Media(url, httpHeaders: channel.httpHeaders));
    } on Object {
      // Roll back: a failing catchup open must not leave failover
      // suspended and the page stuck in catchup mode.
      if (mounted) {
        _exitCatchup();
      } else {
        _session?.resumeFailover();
      }
      rethrow;
    }
  }

  void _exitCatchup() {
    if (!_inCatchup) return;
    setState(() {
      _inCatchup = false;
      _catchupProgramme = null;
    });
    _session?.resumeFailover();
  }

  /// Leaves catchup mode and reopens the current live source.
  void _returnToLive() {
    _exitCatchup();
    final channel = _current;
    unawaited(
      _player.open(Media(channel.streamUrl, httpHeaders: channel.httpHeaders)),
    );
  }

  Future<void> _setRate(double rate) async {
    await _player.setRate(rate);
    if (!mounted) return;
    setState(() => _rate = rate);
  }

  Future<void> _toggleRecord() async {
    if (_recordingBusy) return;
    setState(() => _recordingBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final recording = _recording;
      if (recording != null) {
        await _manageRecording!.stop(recording, _recordingHandle!);
        return;
      }
      final manage = ref.read(manageRecordingProvider);
      final result = await manage.start(_current);
      if (!mounted) {
        await manage.stop(result.recording, result.handle);
        return;
      }
      setState(() {
        _recording = result.recording;
        _recordingHandle = result.handle;
        _manageRecording = manage;
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.recordingStarted)));
      unawaited(_observeRecording(result));
    } on Object catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.recordingFailed(localizedErrorText(l10n, e)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recordingBusy = false);
    }
  }

  Future<void> _observeRecording(StartRecordingResult result) async {
    String? error;
    try {
      await result.done;
    } on Object catch (e) {
      error = '$e';
    }
    if (!mounted || _recording?.id != result.recording.id) return;
    setState(() {
      _recording = null;
      _recordingHandle = null;
      _manageRecording = null;
    });
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? l10n.recordingSaved
              // Capture-done failures carry a raw exception message
              // (network/disk), not a data-layer reason enum.
              : l10n.recordingFailed(error),
        ),
      ),
    );
  }
}
