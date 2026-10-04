import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/application/providers.dart';
import 'package:zerotv_player/features/recording/application/recording_scheduler.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';
import 'package:zerotv_player/features/recording/presentation/recordings_page.dart';

import '../../../helpers/fake_channel_repository.dart';
import '../../../helpers/fake_recording_repository.dart';
import '../../../helpers/fake_scheduled_recording_repository.dart';
import '../../../helpers/localized_app.dart';

void main() {
  final start = DateTime.now().add(const Duration(hours: 2));
  final pending = ScheduledRecording(
    id: 's1',
    channelKey: 'cctv1',
    channelName: 'CCTV-1',
    streamUrl: 'http://a/1',
    title: '晚间剧场',
    startAt: start,
    endAt: start.add(const Duration(hours: 2)),
    createdAt: DateTime(2026, 10, 4),
  );
  final done = ScheduledRecording(
    id: 's2',
    channelKey: 'cctv2',
    channelName: 'CCTV-2',
    streamUrl: 'http://a/2',
    title: '午间新闻',
    startAt: DateTime(2026, 10, 3, 12),
    endAt: DateTime(2026, 10, 3, 12, 30),
    createdAt: DateTime(2026, 10, 2),
    state: ScheduledRecordingState.done,
  );

  late FakeScheduledRecordingRepository scheduled;
  late FakeRecordingRepository recordings;

  Future<void> pumpPage(WidgetTester tester) async {
    scheduled = FakeScheduledRecordingRepository([pending, done]);
    recordings = FakeRecordingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingRepositoryProvider.overrideWithValue(recordings),
          scheduledRecordingRepositoryProvider.overrideWithValue(scheduled),
          // The scheduler is overridden so a cancel never touches the
          // real database or a real HTTP capture.
          recordingSchedulerProvider.overrideWithValue(
            RecordingScheduler(
              schedules: scheduled,
              channels: FakeChannelRepository(),
              manage: ManageRecording(
                repository: recordings,
                recorder: _NoopRecorder(),
                documentsDir: () async => throw UnimplementedError(),
              ),
            ),
          ),
        ],
        child: localizedApp(home: const RecordingsPage()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  Future<void> openScheduledTab(WidgetTester tester) async {
    await tester.tap(find.text('预约'));
    await tester.pumpAndSettle();
  }

  testWidgets('scheduled tab lists rows with state labels', (tester) async {
    await pumpPage(tester);
    await openScheduledTab(tester);

    expect(find.text('晚间剧场'), findsOneWidget);
    expect(find.text('午间新闻'), findsOneWidget);
    expect(find.textContaining('待录制'), findsOneWidget);
    expect(find.textContaining('已完成'), findsOneWidget);
  });

  testWidgets('deleting a finished schedule removes only that row', (
    tester,
  ) async {
    await pumpPage(tester);
    await openScheduledTab(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(scheduled.length, 1);
    expect(scheduled.byId('s1'), isNotNull);
    expect(find.text('午间新闻'), findsNothing);
  });

  testWidgets('cancelling a pending schedule asks for confirmation', (
    tester,
  ) async {
    await pumpPage(tester);
    await openScheduledTab(tester);

    await tester.tap(find.byIcon(Icons.cancel_outlined));
    await tester.pumpAndSettle();
    expect(find.text('取消预约'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(
      scheduled.byId('s1').state,
      ScheduledRecordingState.cancelled,
    );
  });
}

class _NoopRecorder extends StreamRecorder {
  @override
  Future<RecordingHandle> start({
    required Uri url,
    required String filePath,
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError('never fires in these tests');
  }
}
