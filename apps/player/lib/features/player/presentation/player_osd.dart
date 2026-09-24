import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

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
/// selection marked. [labelOf] renders each track's display name.
Future<void> showTrackMenu<T>({
  required BuildContext context,
  required String title,
  required List<T> tracks,
  required T current,
  required String Function(T track) labelOf,
  required Future<void> Function(T track) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final track in tracks)
            ListTile(
              title: Text(labelOf(track)),
              trailing: track == current ? const Icon(Icons.check) : null,
              onTap: () async {
                await onSelected(track);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
    ),
  );
}
