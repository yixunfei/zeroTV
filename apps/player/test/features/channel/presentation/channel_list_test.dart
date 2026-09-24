import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/channel/presentation/channel_list_page.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

import '../../../helpers/fake_channel_repository.dart';
import '../../../helpers/fake_favorites_repository.dart';
import '../../../helpers/fake_watch_history_repository.dart';

void main() {
  const seedChannels = [
    Channel(name: 'CCTV-1', streamUrl: 'http://a/1', groupTitle: '央视'),
    Channel(name: '湖南卫视', streamUrl: 'http://a/2', groupTitle: '卫视'),
  ];

  late FakeFavoritesRepository favorites;
  late FakeWatchHistoryRepository history;

  Future<void> pumpPage(
    WidgetTester tester, {
    Set<String>? favoriteKeys,
    List<HistoryEntry>? historyEntries,
  }) async {
    favorites = FakeFavoritesRepository(favoriteKeys);
    history = FakeWatchHistoryRepository(historyEntries);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelRepositoryProvider.overrideWithValue(
            FakeChannelRepository(
              channels: seedChannels,
              groups: const ['央视', '卫视'],
            ),
          ),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          watchHistoryRepositoryProvider.overrideWithValue(history),
          bootstrapProvider.overrideWith((ref) async => <SyncFailure>[]),
        ],
        child: const MaterialApp(home: ChannelListPage()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('renders group chips and channels', (tester) async {
    await pumpPage(tester);

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('最近'), findsOneWidget);
    expect(find.text('央视'), findsWidgets); // chip + tile subtitle
    expect(find.text('卫视'), findsWidgets);
    expect(find.text('CCTV-1'), findsOneWidget);
    expect(find.text('湖南卫视'), findsOneWidget);
  });

  testWidgets('tapping a group chip filters the channel list', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '央视'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('CCTV-1'), findsOneWidget);
    expect(find.text('湖南卫视'), findsNothing);
  });

  testWidgets('tapping the star toggles the favorite state', (tester) async {
    await pumpPage(tester);

    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.star_border).first);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(await favorites.isFavorite('cctv-1'), isTrue);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('favorites chip shows only favorite channels', (tester) async {
    await pumpPage(tester, favoriteKeys: {'cctv-1'});

    await tester.tap(find.widgetWithText(ChoiceChip, '收藏'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('CCTV-1'), findsOneWidget);
    expect(find.text('湖南卫视'), findsNothing);
  });

  testWidgets('recent chip orders channels by latest watch', (tester) async {
    await pumpPage(
      tester,
      historyEntries: [
        HistoryEntry(
          channelKey: 'cctv-1',
          channelName: 'CCTV-1',
          watchedAt: DateTime(2026, 9, 22, 8),
        ),
        HistoryEntry(
          channelKey: '湖南卫视',
          channelName: '湖南卫视',
          watchedAt: DateTime(2026, 9, 22, 9),
        ),
      ],
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '最近'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('CCTV-1'), findsOneWidget);
    expect(find.text('湖南卫视'), findsOneWidget);
    final recentFirst = tester.getTopLeft(find.text('湖南卫视'));
    final olderSecond = tester.getTopLeft(find.text('CCTV-1'));
    expect(recentFirst.dy, lessThan(olderSecond.dy));
  });

  testWidgets('search filters the list by name substring', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing); // chips hidden in search

    await tester.enterText(find.byType(TextField), 'cctv');
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('CCTV-1'), findsOneWidget);
    expect(find.text('湖南卫视'), findsNothing);
  });

  testWidgets('exiting search restores the full list', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cctv');
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    await tester.tap(find.byIcon(Icons.close));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('CCTV-1'), findsOneWidget);
    expect(find.text('湖南卫视'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
  });

  testWidgets('empty search result shows a dedicated hint', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不存在的频道');
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('没有找到「不存在的频道」'), findsOneWidget);
  });

  testWidgets('resume banner appears when history matches a channel', (
    tester,
  ) async {
    await pumpPage(
      tester,
      historyEntries: [
        HistoryEntry(
          channelKey: 'cctv-1',
          channelName: 'CCTV-1',
          watchedAt: DateTime(2026, 9, 22, 8),
        ),
      ],
    );

    expect(find.text('继续观看：CCTV-1'), findsOneWidget);
  });

  testWidgets('resume banner hides when history has no matching channel', (
    tester,
  ) async {
    await pumpPage(
      tester,
      historyEntries: [
        HistoryEntry(
          channelKey: '已消失频道',
          channelName: '已消失频道',
          watchedAt: DateTime(2026, 9, 22, 8),
        ),
      ],
    );

    expect(find.textContaining('继续观看'), findsNothing);
  });

  testWidgets('dismissing the resume banner hides it for the session', (
    tester,
  ) async {
    await pumpPage(
      tester,
      historyEntries: [
        HistoryEntry(
          channelKey: 'cctv-1',
          channelName: 'CCTV-1',
          watchedAt: DateTime(2026, 9, 22, 8),
        ),
      ],
    );
    expect(find.text('继续观看：CCTV-1'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('继续观看：CCTV-1'), findsNothing);
  });
}
