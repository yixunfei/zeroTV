/// An XMLTV channel entry (metadata used for EPG matching).
class EpgChannel {
  /// Creates an EPG channel entry.
  const EpgChannel({
    required this.id,
    required this.displayName,
    this.iconUrl,
  });

  /// XMLTV channel id.
  final String id;

  /// Display name from the EPG feed.
  final String displayName;

  /// Optional channel icon URL from the EPG feed.
  final String? iconUrl;
}

/// A single programme entry in the electronic programme guide.
class EpgProgram {
  /// Creates a programme entry.
  const EpgProgram({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  /// XMLTV channel id this programme belongs to.
  final String channelId;

  /// Programme title.
  final String title;

  /// Start time (UTC).
  final DateTime start;

  /// End time (UTC).
  final DateTime stop;

  /// Optional description.
  final String? description;
}

/// A parsed XMLTV feed: channel metadata plus programmes.
class EpgFeed {
  /// Creates a feed.
  const EpgFeed({required this.channels, required this.programmes});

  /// Channel metadata entries.
  final List<EpgChannel> channels;

  /// Programme entries.
  final List<EpgProgram> programmes;

  /// An empty feed.
  static const empty = EpgFeed(channels: [], programmes: []);
}
