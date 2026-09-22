import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zerotv_player/core/database/tables.dart';

part 'app_database.g.dart';

/// Application SQLite database (schema v1).
@DriftDatabase(tables: [Subscriptions, Channels, Favorites, WatchHistory])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-disk database in the app documents directory.
  AppDatabase() : super(_openOnDisk());

  /// Creates an in-memory database, for tests.
  AppDatabase.memory()
    : super(
        NativeDatabase.memory(
          setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON'),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: channels 增加 catchupDays / userAgent / referrer。
        await m.addColumn(channels, channels.catchupDays);
        await m.addColumn(channels, channels.userAgent);
        await m.addColumn(channels, channels.referrer);
      }
    },
  );

  static QueryExecutor _openOnDisk() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'zerotv.sqlite'));
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON'),
      );
    });
  }
}
