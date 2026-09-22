import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/channel/presentation/channel_list_page.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

import '../../../helpers/fake_channel_repository.dart';

void main() {
  const seedChannels = [
    Channel(name: 'CCTV-1', streamUrl: 'http://a/1', groupTitle: '央视'),
    Channel(name: '湖南卫视', streamUrl: 'http://a/2', groupTitle: '卫视'),
  ];

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelRepositoryProvider.overrideWithValue(
            FakeChannelRepository(
              channels: seedChannels,
              groups: const ['央视', '卫视'],
            ),
          ),
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
}
