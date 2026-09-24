import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotv_player/app.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

import 'helpers/fake_channel_repository.dart';
import 'helpers/fake_favorites_repository.dart';
import 'helpers/fake_probe_result_repository.dart';
import 'helpers/fake_watch_history_repository.dart';

void main() {
  /// Pumps the full app with a no-op bootstrap and in-memory
  /// repositories (live drift streams are covered by repository unit
  /// tests and intentionally avoided in widget tests).
  Future<void> pumpTestApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelRepositoryProvider.overrideWithValue(
            FakeChannelRepository(),
          ),
          favoritesRepositoryProvider.overrideWithValue(
            FakeFavoritesRepository(),
          ),
          watchHistoryRepositoryProvider.overrideWithValue(
            FakeWatchHistoryRepository(),
          ),
          probeResultRepositoryProvider.overrideWithValue(
            FakeProbeResultRepository(),
          ),
          bootstrapProvider.overrideWith((ref) async => <SyncFailure>[]),
        ],
        child: const ZeroTvApp(),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('app shell renders the channel list empty state', (tester) async {
    await pumpTestApp(tester);

    expect(find.text('zeroTV'), findsOneWidget);
    expect(find.text('还没有任何频道'), findsOneWidget);
    expect(find.byTooltip('添加'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
  });

  testWidgets('add menu offers subscription and single-channel entries', (
    tester,
  ) async {
    await pumpTestApp(tester);

    await tester.tap(find.byTooltip('添加'));
    await tester.pumpAndSettle();

    expect(find.text('添加订阅'), findsOneWidget);
    expect(find.text('添加单频道'), findsOneWidget);
  });

  testWidgets('settings page opens from the app bar', (tester) async {
    await pumpTestApp(tester);

    await tester.tap(find.byTooltip('设置'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('订阅同步'), findsOneWidget);
    expect(find.text('关于 zeroTV'), findsOneWidget);
  });
}
