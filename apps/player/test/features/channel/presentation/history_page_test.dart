import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/channel/presentation/history_page.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

import '../../../helpers/fake_channel_repository.dart';
import '../../../helpers/fake_dead_channel_repository.dart';
import '../../../helpers/fake_favorites_repository.dart';
import '../../../helpers/fake_probe_result_repository.dart';
import '../../../helpers/fake_subscription_repository.dart';
import '../../../helpers/fake_watch_history_repository.dart';
import '../../../helpers/localized_app.dart';

void main() {
  const channels = [
    Channel(name: 'CCTV-1', streamUrl: 'http://a/1', groupTitle: '央视'),
  ];

  HistoryEntry entry(String key, String name, int hour) => HistoryEntry(
    channelKey: key,
    channelName: name,
    watchedAt: DateTime(2026, 9, 22, hour),
  );

  late FakeWatchHistoryRepository history;

  Future<void> pumpPage(
    WidgetTester tester,
    List<HistoryEntry> entries,
  ) async {
    history = FakeWatchHistoryRepository(entries);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelRepositoryProvider.overrideWithValue(
            FakeChannelRepository(channels: channels),
          ),
          watchHistoryRepositoryProvider.overrideWithValue(history),
          favoritesRepositoryProvider.overrideWithValue(
            FakeFavoritesRepository(),
          ),
          deadChannelRepositoryProvider.overrideWithValue(
            FakeDeadChannelRepository(),
          ),
          probeResultRepositoryProvider.overrideWithValue(
            FakeProbeResultRepository(),
          ),
          subscriptionRepositoryProvider.overrideWithValue(
            FakeSubscriptionRepository(const []),
          ),
        ],
        child: localizedApp(home: const HistoryPage()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('lists entries, latest first', (tester) async {
    await pumpPage(tester, [
      entry('cctv-1', 'CCTV-1', 8),
      entry('gone', '已消失频道', 9),
    ]);

    expect(find.text('CCTV-1'), findsOneWidget);
    expect(find.text('已消失频道'), findsOneWidget);
    final goneTop = tester.getTopLeft(find.text('已消失频道'));
    final cctvTop = tester.getTopLeft(find.text('CCTV-1'));
    expect(goneTop.dy, lessThan(cctvTop.dy));
  });

  testWidgets('vanished channel is greyed out with a hint', (tester) async {
    await pumpPage(tester, [entry('gone', '已消失频道', 9)]);

    expect(find.textContaining('频道已不在当前订阅中'), findsOneWidget);
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.enabled, isFalse);
  });

  testWidgets('delete icon removes only that entry', (tester) async {
    await pumpPage(tester, [
      entry('cctv-1', 'CCTV-1', 8),
      entry('gone', '已消失频道', 9),
    ]);

    await tester.tap(find.byTooltip('删除').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    final remaining = await history.watchRecent().first;
    expect(remaining, hasLength(1));
    expect(remaining.single.channelKey, 'cctv-1');
    expect(find.text('已消失频道'), findsNothing);
  });

  testWidgets('clear-all empties the repository after confirmation', (
    tester,
  ) async {
    await pumpPage(tester, [entry('cctv-1', 'CCTV-1', 8)]);

    await tester.tap(find.byTooltip('清空历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清空历史'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(await history.watchRecent().first, isEmpty);
    expect(find.text('还没有观看记录'), findsOneWidget);
  });
}
