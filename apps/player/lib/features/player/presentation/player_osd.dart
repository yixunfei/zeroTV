import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:zerotv_player/features/player/presentation/player_chrome.dart';

/// Aspect-ratio presets offered by the player OSD, mapped to [BoxFit].
enum PlayerAspect {
  /// Preserve aspect ratio, letterboxed (default).
  contain(BoxFit.contain),

  /// Preserve aspect ratio, cropped to fill.
  cover(BoxFit.cover),

  /// Stretch to fill (ignores aspect ratio).
  fill(BoxFit.fill),

  /// Fit width, may overflow vertically.
  fitWidth(BoxFit.fitWidth),

  /// Fit height, may overflow horizontally.
  fitHeight(BoxFit.fitHeight);

  const PlayerAspect(this.fit);

  /// The corresponding [BoxFit].
  final BoxFit fit;

  /// The next preset in the cycle.
  PlayerAspect get next {
    final i = (index + 1) % PlayerAspect.values.length;
    return PlayerAspect.values[i];
  }
}

/// Playback speed presets offered by the player OSD.
const playerRatePresets = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

/// Builds a display label for an audio/subtitle track, preferring its
/// title or language and falling back to its id.
String trackLabel(AudioTrack track) =>
    _label(track.id, track.title, track.language);

/// Builds a display label for a subtitle track.
String subtitleLabel(SubtitleTrack track) =>
    _label(track.id, track.title, track.language);

String _label(String id, String? title, String? language) {
  if (title != null && title.trim().isNotEmpty) return title.trim();
  if (language != null && language.trim().isNotEmpty) return language.trim();
  return id;
}

/// A bottom-sheet menu for choosing among [tracks], with the current
/// selection marked. [labelOf] renders each track's display name and
/// [idOf] identifies tracks for the checkmark (media_kit track objects
/// do not implement value equality).
Future<void> showTrackMenu<T>({
  required BuildContext context,
  required String title,
  required List<T> tracks,
  required T current,
  required String Function(T track) idOf,
  required String Function(T track) labelOf,
  required Future<void> Function(T track) onSelected,
}) async {
  final selected = await showPlayerSheet<T>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final track in tracks)
            ListTile(
              selected: idOf(track) == idOf(current),
              selectedTileColor: Colors.white10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              title: Text(
                labelOf(track),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: idOf(track) == idOf(current)
                  ? const Icon(Icons.check, color: Color(0xff70c5ff))
                  : null,
              onTap: () => Navigator.of(context).pop(track),
            ),
        ],
      ),
    ),
  );
  if (selected != null) await onSelected(selected);
}
