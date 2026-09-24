import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:stream_probe/stream_probe.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/features/detection/application/run_availability_probe.dart';
import 'package:zerotv_player/features/detection/data/drift_probe_result_repository.dart';

/// Provides the [ProbeResultRepository].
final probeResultRepositoryProvider = Provider<ProbeResultRepository>((ref) {
  return DriftProbeResultRepository(ref.watch(appDatabaseProvider));
});

/// The shared HTTP stream prober used by the detection feature.
final streamProberProvider = Provider<StreamProber>((ref) {
  final prober = HttpStreamProber();
  ref.onDispose(prober.close);
  return prober;
});

/// Provides the [RunAvailabilityProbe] use case, honoring the configured
/// probe concurrency.
final runAvailabilityProbeProvider = Provider<RunAvailabilityProbe>((ref) {
  final concurrency = ref.watch(appSettingsProvider).probeConcurrency;
  return RunAvailabilityProbe(
    prober: ref.watch(streamProberProvider),
    results: ref.watch(probeResultRepositoryProvider),
    concurrency: concurrency,
  );
});

/// Latest stored probe result per channel identity key.
final probeResultsProvider = StreamProvider<Map<String, ProbeResult>>((ref) {
  return ref.watch(probeResultRepositoryProvider).watchAll();
});
