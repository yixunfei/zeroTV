import 'package:flutter_test/flutter_test.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/channel/data/drift_favorites_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftFavoritesRepository repo;

  setUp(() {
    database = db.AppDatabase.memory();
    repo = DriftFavoritesRepository(database);
  });

  tearDown(() => database.close());

  test('add marks a key as favorite; adding twice is a no-op', () async {
    expect(await repo.isFavorite('cctv1'), isFalse);
    await repo.add('cctv1');
    await repo.add('cctv1');
    expect(await repo.isFavorite('cctv1'), isTrue);
    expect(await repo.watchKeys().first, {'cctv1'});
  });

  test('remove un-marks the key', () async {
    await repo.add('cctv1');
    await repo.remove('cctv1');
    expect(await repo.isFavorite('cctv1'), isFalse);
    expect(await repo.watchKeys().first, isEmpty);
  });

  test('watchKeys emits updates', () async {
    final emissions = <Set<String>>[];
    final sub = repo.watchKeys().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await repo.add('cctv1');
    await pumpEventQueue();
    expect(emissions, hasLength(greaterThanOrEqualTo(2)));
    expect(emissions.first, isEmpty);
    expect(emissions.last, {'cctv1'});
  });
}
