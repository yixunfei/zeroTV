import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/player/presentation/player_chrome.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Programme history for the channel currently being watched.
class PlayerHistoryPanel extends StatelessWidget {
  /// Creates a scrollable, source-backed catchup panel.
  const PlayerHistoryPanel({
    required this.programmes,
    required this.onClose,
    required this.onSelected,
    this.selected,
    super.key,
  });

  /// Loading result owned by the playback page.
  final Future<List<EpgProgram>>? programmes;

  /// Closes the overlay without leaving playback.
  final VoidCallback onClose;

  /// Opens a programme through the channel's catchup source.
  final Future<void> Function(EpgProgram programme) onSelected;

  /// Programme currently playing in catchup mode.
  final EpgProgram? selected;

  @override
  Widget build(BuildContext context) => Theme(
    data: playerTheme(Theme.of(context)),
    child: Material(
      color: const Color(0xff11151c),
      elevation: 18,
      shadowColor: Colors.black,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.white12),
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _header(context),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: FutureBuilder<List<EpgProgram>>(
                future: programmes,
                builder: _content,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
    child: Row(
      children: [
        const Icon(Icons.history_rounded, color: Colors.white60, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            AppLocalizations.of(context).catchupTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).close,
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ],
    ),
  );

  Widget _content(
    BuildContext context,
    AsyncSnapshot<List<EpgProgram>> snapshot,
  ) {
    final l10n = AppLocalizations.of(context);
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (snapshot.hasError) {
      return _message(
        l10n.playbackFailed('${snapshot.error}'),
        Icons.error_outline,
      );
    }
    final sorted = [...?snapshot.data]
      ..sort((a, b) => b.start.compareTo(a.start));
    if (sorted.isEmpty) {
      return _message(l10n.noCatchupProgrammes, Icons.history_rounded);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final programme = sorted[index];
        final startsDate =
            index == 0 ||
            !DateUtils.isSameDay(
              sorted[index - 1].start.toLocal(),
              programme.start.toLocal(),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsDate)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                child: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatFullDate(programme.start.toLocal()),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            _ProgrammeTile(
              programme: programme,
              selected:
                  selected?.channelId == programme.channelId &&
                  selected?.start == programme.start,
              onTap: () => unawaited(onSelected(programme)),
            ),
          ],
        );
      },
    );
  }

  Widget _message(String text, IconData icon) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    ),
  );
}

class _ProgrammeTile extends StatelessWidget {
  const _ProgrammeTile({
    required this.programme,
    required this.selected,
    required this.onTap,
  });
  final EpgProgram programme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = TimeOfDay.fromDateTime(
      programme.start.toLocal(),
    ).format(context);
    final stop = TimeOfDay.fromDateTime(
      programme.stop.toLocal(),
    ).format(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected
            ? accent.withValues(alpha: .12)
            : Colors.white.withValues(alpha: .04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? accent.withValues(alpha: .55)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$start – $stop',
                        style: TextStyle(
                          color: selected ? accent : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        programme.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.equalizer_rounded
                      : Icons.play_circle_outline_rounded,
                  color: selected ? accent : Colors.white54,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
