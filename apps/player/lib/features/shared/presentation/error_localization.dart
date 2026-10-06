import 'package:zerotv_player/features/recording/domain/recording_exception.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Translates data-layer exceptions into localized, user-facing text.
///
/// Data layers throw typed exceptions carrying machine-readable reasons
/// (see [SubscriptionFetchException] and [RecordingException]); this is
/// the single place that maps them onto locale strings so error text
/// never leaks the wrong language into the UI. Unknown errors fall back
/// to their `toString()` diagnostic.
String localizedErrorText(AppLocalizations l10n, Object error) {
  switch (error) {
    case SubscriptionFetchException(:final reason):
      return switch (reason) {
        SyncErrorReason.fileMissing => l10n.errFileMissing,
        SyncErrorReason.fileReadFailed => l10n.errFileReadFailed,
        SyncErrorReason.emptyBody => l10n.errEmptyBody,
        SyncErrorReason.notAPlaylist => l10n.errNotAPlaylist,
        SyncErrorReason.allMirrorsUnreachable => l10n.errAllMirrorsUnreachable,
        SyncErrorReason.noValidChannels => l10n.errNoValidChannels,
        SyncErrorReason.pastedNoValidChannels => l10n.errPastedNoValidChannels,
        SyncErrorReason.epgEmptyBody => l10n.errEpgEmptyBody,
        SyncErrorReason.epgFetchFailed => l10n.errEpgFetchFailed,
        SyncErrorReason.epgParseFailed => l10n.errEpgParseFailed,
      };
    case RecordingException(:final reason, :final statusCode):
      return switch (reason) {
        RecordingErrorReason.unsupportedScheme => l10n.errRecordScheme,
        RecordingErrorReason.unsupportedPlaylist => l10n.errRecordPlaylist,
        RecordingErrorReason.httpStatus =>
          statusCode == null || statusCode < 0
              ? l10n.errRecordHttpStatus
              : l10n.errRecordHttpStatusCode(statusCode),
        RecordingErrorReason.unsupportedContentType =>
          l10n.errRecordContentType,
      };
    case UnsupportedError():
      // Thrown for subscription kinds that cannot re-sync; the UI layers
      // already disable those actions, so this is a defensive fallback.
      return l10n.syncUnsupported;
    default:
      return '$error';
  }
}
