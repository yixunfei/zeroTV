/// Scroll performance test: renders the channel list with 5000+
/// channels, drives flings through it, and reports frame-time
/// statistics (avg / p95 / p99 / jank %) on stdout.
///
/// Run with:
///   flutter test integration_test/perf/scroll_perf_test.dart -d windows
///
/// The test does not assert a hard threshold — CI machines vary too
/// much for that to be stable. Instead it prints a summary line that
/// humans (or log-scraping tooling) can inspect. A generous sanity
/// ceiling is asserted so catastrophic regressions still fail loudly.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/channel/presentation/channel_list_page.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/epg/application/epg_index.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

import '../../test/helpers/fake_channel_repository.dart';
import '../../test/helpers/fake_favorites_repository.dart';
import '../../test/helpers/fake_probe_result_repository.dart';
import '../../test/helpers/fake_subscription_repository.dart';
import '../../test/helpers/fake_watch_history_repository.dart';
import '../../test/helpers/localized_app.dart';
import 'perf_fixture.dart';
import 'perf_metrics.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('5000-channel list scrolls at 60fps-class frame times', (
    tester,
  ) async {
    final channels = buildPerfChannels();
    final groups = perfGroupsOf(channels);

    SharedPreferences.setMockInitialValues({
      'settings.disclaimerAccepted': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          channelRepositoryProvider.overrideWithValue(
            FakeChannelRepository(channels: channels, groups: groups),
          ),
          favoritesRepositoryProvider.overrideWithValue(
            FakeFavoritesRepository(const {}),
          ),
          watchHistoryRepositoryProvider.overrideWithValue(
            FakeWatchHistoryRepository(const []),
          ),
          probeResultRepositoryProvider.overrideWithValue(
            FakeProbeResultRepository(const {}),
          ),
          subscriptionRepositoryProvider.overrideWithValue(
            FakeSubscriptionRepository(const []),
          ),
          epgIndexProvider.overrideWith((ref) async => EpgIndex.empty),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: localizedApp(home: const ChannelListPage()),
      ),
    );
    // Let streams settle so the list is built.
    await tester.pumpAndSettle();

    final listFinder = find.byType(ListView);
    expect(listFinder, findsWidgets);
    // The vertical list is the last ListView (chips row is horizontal and
    // comes first in the widget tree).
    final verticalList = listFinder.last;

    final recorder = FrameTimeRecorder();
    binding.addTimingsCallback(recorder.onTiming);

    try {
      // Scroll down through the whole list in repeated flings, then back
      // up. Each fling covers roughly one screen of items; 5000 channels
      // at ~64px per tile means hundreds of screens, so we don't try to
      // exhaust the list — just produce a representative workload.
      const flingCount = 30;
      for (var i = 0; i < flingCount; i++) {
        await tester.fling(
          verticalList,
          const Offset(0, -600),
          2500,
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
      for (var i = 0; i < flingCount; i++) {
        await tester.fling(verticalList, const Offset(0, 600), 2500);
        await tester.pump(const Duration(milliseconds: 120));
      }
      // Drain any residual frames.
      await tester.pumpAndSettle();
    } finally {
      binding.removeTimingsCallback(recorder.onTiming);
    }

    final stats = recorder.summarize();
    // Perf numbers need to reach stdout even in release-flavored test
    // runs; this is intentional tooling output, not debug residue.
    // ignore: avoid_print
    print(
      '[PERF scroll] samples=${stats.sampleCount} '
      'avg=${stats.averageMs.toStringAsFixed(2)}ms '
      'p95=${stats.p95Ms.toStringAsFixed(2)}ms '
      'p99=${stats.p99Ms.toStringAsFixed(2)}ms '
      'max=${stats.maxMs.toStringAsFixed(2)}ms '
      'jank=${(stats.jankRatio * 100).toStringAsFixed(1)}% '
      'frames>16.67ms=${stats.jankFrames}',
    );

    expect(stats.sampleCount, greaterThan(0), reason: 'no frames recorded');

    // Sanity ceiling: if even the *average* frame blows past 50ms the
    // list is unusably broken and we want the test to fail loudly.
    // Target remains 60fps (16.67ms); we don't hard-assert it because
    // debug builds and software rasterizers legitimately miss it.
    expect(
      stats.averageMs,
      lessThan(50),
      reason:
          'average frame time ${stats.averageMs}ms is far above '
          'any usable budget; check for synchronous work in itemBuilder',
    );
  });
}

/// Collects [FrameTiming] samples from the scheduler.
class FrameTimeRecorder {
  final List<FrameTiming> _samples = [];

  /// Callback shape required by [WidgetsBinding.addTimingsCallback].
  void onTiming(List<FrameTiming> timings) {
    _samples.addAll(timings);
  }

  /// Builds a [PerfStats] from all collected samples.
  PerfStats summarize() => PerfStats.fromTimings(_samples);
}
