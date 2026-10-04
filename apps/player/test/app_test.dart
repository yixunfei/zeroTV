import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/app.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

import 'helpers/fake_channel_repository.dart';
import 'helpers/fake_dead_channel_repository.dart';
import 'helpers/fake_favorites_repository.dart';
import 'helpers/fake_probe_result_repository.dart';
import 'helpers/fake_subscription_repository.dart';
import 'helpers/fake_watch_history_repository.dart';

void main() {
  /// Pumps the full app with a no-op bootstrap and in-memory
  /// repositories (live drift streams are covered by repository unit
  /// tests and intentionally avoided in widget tests).
  Future<void> pumpTestApp(
    WidgetTester tester, {
    bool disclaimerAccepted = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings.disclaimerAccepted': disclaimerAccepted,
      'settings.locale': 'zh',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
          subscriptionRepositoryProvider.overrideWithValue(
            FakeSubscriptionRepository(),
          ),
          deadChannelRepositoryProvider.overrideWithValue(
            FakeDeadChannelRepository(),
          ),
          bootstrapProvider.overrideWith((ref) async {}),
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

    // The empty state also offers "添加订阅", hence at least one match.
    expect(find.text('添加订阅'), findsWidgets);
    expect(find.text('添加单频道'), findsOneWidget);
  });

  testWidgets('settings page opens from the app bar', (tester) async {
    await pumpTestApp(tester);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('订阅管理'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('关于 zeroTV'), 200);
    expect(find.text('关于 zeroTV'), findsWidgets);
  });

  testWidgets('about page shows the standing disclaimer', (tester) async {
    await pumpTestApp(tester);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(ListTile, '关于 zeroTV');
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('免责声明'), findsOneWidget);
    expect(find.textContaining('不存储、不分发'), findsOneWidget);
  });

  testWidgets('first launch blocks on the disclaimer until accepted', (
    tester,
  ) async {
    await pumpTestApp(tester, disclaimerAccepted: false);

    expect(find.text('使用须知'), findsOneWidget);
    expect(find.textContaining('不存储、不分发'), findsOneWidget);

    await tester.tap(find.text('我已了解'));
    await tester.pumpAndSettle();

    expect(find.text('使用须知'), findsNothing);
    expect(find.text('zeroTV'), findsOneWidget);
  });
}
