import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/toggle_favorite.dart';

import '../../../helpers/fake_favorites_repository.dart';

void main() {
  late FakeFavoritesRepository favorites;
  late ToggleFavorite toggle;

  setUp(() {
    favorites = FakeFavoritesRepository();
    toggle = ToggleFavorite(favorites: favorites);
  });

  test('toggles add then remove', () async {
    const channel = Channel(
      name: 'CCTV-1',
      streamUrl: 'http://a/1',
      tvgId: 'cctv1',
    );
    await toggle(channel);
    expect(await favorites.isFavorite('cctv1'), isTrue);
    await toggle(channel);
    expect(await favorites.isFavorite('cctv1'), isFalse);
  });

  test('keys by normalized name when tvgId is absent', () async {
    const channel = Channel(name: '湖南卫视', streamUrl: 'http://a/2');
    await toggle(channel);
    expect(await favorites.isFavorite('湖南卫视'), isTrue);
  });
}
