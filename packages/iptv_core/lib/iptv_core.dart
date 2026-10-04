/// zeroTV domain model and port interfaces.
///
/// Pure Dart, zero Flutter dependency: usable in isolates and unit tests.
library;

export 'src/entities/channel.dart';
export 'src/entities/dead_channel.dart';
export 'src/entities/epg.dart';
export 'src/entities/history_entry.dart';
export 'src/entities/probe_result.dart';
export 'src/entities/recording.dart';
export 'src/entities/scheduled_recording.dart';
export 'src/entities/subscription.dart';
export 'src/interfaces/epg_provider.dart';
export 'src/interfaces/playlist_parser.dart';
export 'src/interfaces/stream_prober.dart';
export 'src/interfaces/subscription_source.dart';
export 'src/repositories/channel_repository.dart';
export 'src/repositories/dead_channel_repository.dart';
export 'src/repositories/epg_repository.dart';
export 'src/repositories/favorites_repository.dart';
export 'src/repositories/probe_result_repository.dart';
export 'src/repositories/recording_repository.dart';
export 'src/repositories/scheduled_recording_repository.dart';
export 'src/repositories/subscription_repository.dart';
export 'src/repositories/watch_history_repository.dart';
