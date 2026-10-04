import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/epg/data/drift_epg_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftEpgRepository epg;

  final feed = EpgFeed(
    channels: const [
      EpgChannel(id: 'cctv1', displayName: 'CCTV-1', iconUrl: 'http://l/1'),
      EpgChannel(id: 'hunan', displayName: '湖南卫视'),
    ],
    programmes: [
      EpgProgram(
        channelId: 'cctv1',
        title: '新闻联播',
        start: DateTime.utc(2026, 9, 24, 11),
        stop: DateTime.utc(2026, 9, 24, 11, 30),
      ),
      EpgProgram(
        channelId: 'cctv1',
        title: '焦点访谈',
        start: DateTime.utc(2026, 9, 24, 11, 30),
        stop: DateTime.utc(2026, 9, 24, 12),
        description: '深度报道',
      ),
      EpgProgram(
        channelId: 'hunan',
        title: '快乐大本营',
        start: DateTime.utc(2026, 9, 24, 12),
        stop: DateTime.utc(2026, 9, 24, 13),
      ),
    ],
  );

  setUp(() {
    database = db.AppDatabase.memory();
    epg = DriftEpgRepository(database);
  });

  tearDown(() => database.close());

  test(
    'replaceFeed then programmesFor returns overlapping programmes',
    () async {
      await epg.replaceFeed(feed);

      final window = await epg.programmesFor(
        'cctv1',
        DateTime.utc(2026, 9, 24, 11, 15),
        DateTime.utc(2026, 9, 24, 11, 45),
      );
      expect(window.map((p) => p.title).toList(), ['新闻联播', '焦点访谈']);
      expect(window.last.description, '深度报道');
    },
  );

  test('programmesFor excludes programmes outside the window', () async {
    await epg.replaceFeed(feed);
    final window = await epg.programmesFor(
      'cctv1',
      DateTime.utc(2026, 9, 24, 12),
      DateTime.utc(2026, 9, 24, 13),
    );
    expect(window, isEmpty);
  });

  test('programmesInWindow returns all channels ordered by start', () async {
    await epg.replaceFeed(feed);
    final window = await epg.programmesInWindow(
      DateTime.utc(2026, 9, 24, 11),
      DateTime.utc(2026, 9, 24, 13),
    );
    expect(window.map((p) => p.title).toList(), [
      '新闻联播',
      '焦点访谈',
      '快乐大本营',
    ]);
  });

  test('allChannels returns feed metadata', () async {
    await epg.replaceFeed(feed);
    final channels = await epg.allChannels();
    expect(channels, hasLength(2));
    expect(channels.first.iconUrl, 'http://l/1');
  });

  test('replaceFeed replaces instead of appending', () async {
    await epg.replaceFeed(feed);
    await epg.replaceFeed(
      EpgFeed(
        channels: const [EpgChannel(id: 'cctv1', displayName: 'CCTV-1')],
        programmes: [
          EpgProgram(
            channelId: 'cctv1',
            title: '新节目',
            start: DateTime.utc(2026, 9, 24, 11),
            stop: DateTime.utc(2026, 9, 24, 11, 30),
          ),
        ],
      ),
    );

    final channels = await epg.allChannels();
    expect(channels, hasLength(1));
    final window = await epg.programmesInWindow(
      DateTime.utc(2026, 9, 24, 11),
      DateTime.utc(2026, 9, 24, 12),
    );
    expect(window.map((p) => p.title).toList(), ['新节目']);
  });

  test('replaceFeed ignores duplicate channel ids', () async {
    await epg.replaceFeed(
      const EpgFeed(
        channels: [
          EpgChannel(id: 'cctv1', displayName: 'CCTV-1'),
          EpgChannel(
            id: 'cctv1',
            displayName: 'CCTV-1 duplicate',
            iconUrl: 'http://l/duplicate.png',
          ),
        ],
        programmes: [],
      ),
    );

    final channels = await epg.allChannels();
    expect(channels, hasLength(1));
    expect(channels.single.displayName, 'CCTV-1');
  });

  test('clear removes all stored EPG data', () async {
    await epg.replaceFeed(feed);
    await epg.clear();
    expect(await epg.allChannels(), isEmpty);
    expect(
      await epg.programmesInWindow(
        DateTime.utc(2026, 9, 24),
        DateTime.utc(2026, 9, 25),
      ),
      isEmpty,
    );
  });
}
