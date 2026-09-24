import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/detection/data/drift_probe_result_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftProbeResultRepository results;

  setUp(() {
    database = db.AppDatabase.memory();
    results = DriftProbeResultRepository(database);
  });

  tearDown(() => database.close());

  test('save then watchAll returns the result', () async {
    final checkedAt = DateTime(2026, 9, 22, 8);
    await results.save(
      'cctv1',
      ProbeResult(
        url: 'http://a/1',
        status: ProbeStatus.ok,
        checkedAt: checkedAt,
        latency: const Duration(milliseconds: 42),
        httpStatus: 200,
      ),
    );

    final all = await results.watchAll().first;
    expect(all, hasLength(1));
    final r = all['cctv1']!;
    expect(r.status, ProbeStatus.ok);
    expect(r.latency, const Duration(milliseconds: 42));
    expect(r.httpStatus, 200);
  });

  test('save replaces the previous result for the same key', () async {
    final at = DateTime(2026, 9, 22, 8);
    await results.save(
      'cctv1',
      ProbeResult(url: 'http://a/1', status: ProbeStatus.ok, checkedAt: at),
    );
    await results.save(
      'cctv1',
      ProbeResult(
        url: 'http://a/1',
        status: ProbeStatus.dead,
        checkedAt: at,
        error: 'no response',
      ),
    );

    final all = await results.watchAll().first;
    expect(all, hasLength(1));
    expect(all['cctv1']!.status, ProbeStatus.dead);
    expect(all['cctv1']!.error, 'no response');
  });

  test('clear removes every stored result', () async {
    await results.save(
      'cctv1',
      ProbeResult(
        url: 'http://a/1',
        status: ProbeStatus.ok,
        checkedAt: DateTime(2026, 9, 22, 8),
      ),
    );
    await results.clear();
    expect(await results.watchAll().first, isEmpty);
  });
}
