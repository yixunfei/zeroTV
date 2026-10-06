import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/epg/application/epg_settings.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';

void main() {
  Future<SharedPreferences> prefsWith([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('adopts the playlist EPG URL when none is configured', () async {
    final prefs = await prefsWith();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(adoptPlaylistEpgUrlProvider)(
      Uri.parse('https://example.com/epg.xml'),
    );

    expect(
      EpgSettings(prefs).url,
      Uri.parse('https://example.com/epg.xml'),
    );
  });

  test('never overwrites an explicitly configured EPG URL', () async {
    final prefs = await prefsWith({
      'epg_url': 'https://user.example.com/my-epg.xml',
    });
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(adoptPlaylistEpgUrlProvider)(
      Uri.parse('https://example.com/other-epg.xml'),
    );

    expect(
      EpgSettings(prefs).url,
      Uri.parse('https://user.example.com/my-epg.xml'),
    );
  });
}
