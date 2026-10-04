part of 'player_page.dart';

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: player.state.buffering,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .62),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

/// Hint shown while the session fails over to a backup source, so the
/// spinner during automatic failover is not unexplained.
class _SwitchingSourceHint extends StatelessWidget {
  const _SwitchingSourceHint({required this.session});

  final PlaybackSession session;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(
              context,
            ).switchingSource(session.index + 1, session.sources.length),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Terminal playback failure panel with recovery actions: retry from
/// the first source, pick another source, or leave the page.
class _PlaybackErrorPanel extends StatelessWidget {
  const _PlaybackErrorPanel({
    required this.error,
    required this.hasMultipleSources,
    required this.onRetry,
    required this.onShowSources,
  });

  final String error;
  final bool hasMultipleSources;
  final VoidCallback onRetry;
  final VoidCallback onShowSources;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: const Color(0xff15171c).withValues(alpha: .96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.playbackFailed(error),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
                if (hasMultipleSources)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onShowSources,
                    icon: const Icon(Icons.playlist_play_outlined),
                    label: Text(l10n.selectSource),
                  ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    l10n.back,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
