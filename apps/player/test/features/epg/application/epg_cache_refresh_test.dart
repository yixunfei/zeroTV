import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/core/database/app_database.dart' show AppDatabase;
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/epg/data/drift_epg_repository.dart';

void main() {
  test(
    'first refresh updates an empty index and an open daily guide',
    () async {
      SharedPreferences.setMockInitialValues({
        'epg_url': 'https://example.com/epg.xml',
      });
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase.memory();
      final now = DateTime.now();
      final feed = EpgFeed(
        channels: const [EpgChannel(id: 'news', displayName: 'News')],
        programmes: [
          EpgProgram(
            channelId: 'news',
            title: 'Updated programme',
            start: now.subtract(const Duration(minutes: 5)),
            stop: now.add(const Duration(hours: 1)),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          epgRepositoryProvider.overrideWithValue(
            DriftEpgRepository(database),
          ),
          epgFeedProvider.overrideWithValue(_FeedProvider(feed)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      final guide = channelGuideProvider((epgId: 'news', day: now));
      container
        ..listen(epgIndexProvider, (_, _) {})
        ..listen(guide, (_, _) {});
      expect((await container.read(epgIndexProvider.future)).isEmpty, isTrue);
      expect(await container.read(guide.future), isEmpty);

      expect(await container.read(refreshEpgProvider)(), isTrue);

      final index = await container.read(epgIndexProvider.future);
      expect(index.knownEpgIds, contains('news'));
      expect(
        (await container.read(guide.future)).map((p) => p.title),
        ['Updated programme'],
      );
    },
  );
}

class _FeedProvider implements EpgProvider {
  _FeedProvider(this.feed);

  final EpgFeed feed;

  @override
  Future<EpgFeed> fetch(Uri uri) async => feed;
}
