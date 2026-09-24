import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';
import 'package:zerotv_player/features/subscription/presentation/subscriptions_page.dart';

import '../../../helpers/fake_channel_repository.dart';
import '../../../helpers/fake_subscription_repository.dart';
import '../../../helpers/localized_app.dart';

void main() {
  final remote = Subscription(
    id: 's1',
    name: '默认源',
    kind: SubscriptionKind.remoteUrl,
    uri: 'https://example.com/a.m3u8',
    lastSyncedAt: DateTime(2026, 9, 22, 8),
  );
  const pasted = Subscription(
    id: 's2',
    name: '粘贴的',
    kind: SubscriptionKind.pastedText,
    enabled: false,
  );

  late FakeSubscriptionRepository subscriptions;

  Future<void> pumpPage(WidgetTester tester) async {
    subscriptions = FakeSubscriptionRepository([remote, pasted]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(subscriptions),
          channelRepositoryProvider.overrideWithValue(
            FakeChannelRepository(counts: const {'s1': 120, 's2': 3}),
          ),
        ],
        child: localizedApp(home: const SubscriptionsPage()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  Future<void> openMenu(WidgetTester tester, {required bool second}) async {
    final menus = find.byType(PopupMenuButton<String>);
    await tester.tap(second ? menus.last : menus.first);
    // Popup routes animate (~300ms); fixed pumps finish too early and
    // the following tap misses the half-open menu. Fakes have no
    // pending timers, so settling is safe.
    await tester.pumpAndSettle();
  }

  testWidgets('renders rows with kind, count and sync labels', (tester) async {
    await pumpPage(tester);

    expect(find.text('默认源'), findsOneWidget);
    expect(find.text('粘贴的'), findsOneWidget);
    expect(find.textContaining('远程 URL · 120 个频道'), findsOneWidget);
    expect(find.textContaining('粘贴导入 · 3 个频道 · 从未同步'), findsOneWidget);
  });

  testWidgets('pasted subscription has sync disabled', (tester) async {
    await pumpPage(tester);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(2));
    expect(switches[0].onChanged, isNotNull);
    expect(switches[1].onChanged, isNull);

    await openMenu(tester, second: true);
    final syncItem = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, '立即同步'),
    );
    expect(syncItem.enabled, isFalse);
  });

  testWidgets('toggling the switch disables auto-sync', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(Switch).first);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    final stored = (await subscriptions.getAll()).first;
    expect(stored.enabled, isFalse);
    final updated = tester.widget<Switch>(find.byType(Switch).first);
    expect(updated.value, isFalse);
  });

  testWidgets('rename flow updates the subscription name', (tester) async {
    await pumpPage(tester);

    await openMenu(tester, second: false);
    await tester.tap(find.text('改名'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  新名字  ');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect((await subscriptions.getAll()).first.name, '新名字');
    expect(find.text('新名字'), findsOneWidget);
  });

  testWidgets('delete flow removes the subscription after confirm', (
    tester,
  ) async {
    await pumpPage(tester);

    await openMenu(tester, second: true);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('收藏与观看历史保留'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    final remaining = await subscriptions.getAll();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, 's1');
    expect(find.text('粘贴的'), findsNothing);
  });
}
