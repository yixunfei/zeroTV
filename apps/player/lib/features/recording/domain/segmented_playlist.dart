/// Whether [url] looks like a segmented (HLS/DASH) playlist rather
/// than a direct stream.
///
/// Single source of truth for both the record-button gating in the
/// player UI and the playlist rejection in `StreamRecorder`: both
/// sides must agree, or the UI would offer recording the recorder must
/// reject (or vice versa).
///
/// Matches `.m3u`/`.m3u8`/`.mpd` at the end of the URL path or before
/// its query string, case-insensitively. Path-less URLs with the
/// extension inside the query (e.g. `/play?file=x.m3u8`) are not
/// classified as playlists: the recorder's content-type check remains
/// the authoritative guard for those.
bool isSegmentedPlaylistUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return RegExp(
    r'\.(m3u8?|mpd)(\?|$)',
    caseSensitive: false,
  ).hasMatch(uri.path);
}
