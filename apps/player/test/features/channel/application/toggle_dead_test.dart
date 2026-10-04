import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/toggle_dead.dart';

import '../../../helpers/fake_dead_channel_repository.dart';

void main() {
  const channel = Channel(
    name: 'CCTV-1',
    streamUrl: 'http://a/1',
    tvgId: 'cctv1',
  );

  test('marks a live channel as dead', () async {
    final repo = FakeDeadChannelRepository();
    final toggle = ToggleDead(dead: repo);

    await toggle(channel, currentlyDead: false);

    expect(await repo.watchKeys().first, {'cctv1'});
    final entry = (await repo.watchAll().first).single;
    expect(entry.channelName, 'CCTV-1');
    expect(entry.streamUrl, 'http://a/1');
  });

  test('revives a dead channel', () async {
    final repo = FakeDeadChannelRepository({'cctv1'});
    final toggle = ToggleDead(dead: repo);

    await toggle(channel, currentlyDead: true);

    expect(await repo.watchKeys().first, isEmpty);
  });

  test('falls back to the normalized name when tvgId is absent', () async {
    final repo = FakeDeadChannelRepository();
    final toggle = ToggleDead(dead: repo);

    await toggle(
      const Channel(name: '湖南卫视', streamUrl: 'http://a/2'),
      currentlyDead: false,
    );

    expect(await repo.watchKeys().first, {'湖南卫视'});
  });
}
