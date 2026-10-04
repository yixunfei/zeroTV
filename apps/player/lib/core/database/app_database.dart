import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zerotv_player/core/database/tables.dart';

part 'app_database.g.dart';

/// Application SQLite database (schema v9).
@DriftDatabase(
  tables: [
    Subscriptions,
    Channels,
    Favorites,
    WatchHistory,
    ProbeResults,
    EpgChannels,
    EpgProgrammes,
    Recordings,
    ScheduledRecordings,
    DeadChannels,
  ],
)
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
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: channels 增加 catchupDays / userAgent / referrer。
        await m.addColumn(channels, channels.catchupDays);
        await m.addColumn(channels, channels.userAgent);
        await m.addColumn(channels, channels.referrer);
      }
      if (from < 3) {
        // v3: 新增 probe_results（可用性检测结果）。
        await m.createTable(probeResults);
      }
      if (from < 4) {
        // v4: 新增 epg_channels / epg_programmes（EPG 数据）。
        await m.createTable(epgChannels);
        await m.createTable(epgProgrammes);
      }
      if (from < 5) {
        // v5: 新增 recordings（录制文件）。
        await m.createTable(recordings);
      }
      if (from < 6) {
        // v6: subscriptions 增加 channelGroupPrefix（订阅级频道分组前缀）；
        // 新增 dead_channels（用户标记的失效频道）。
        await m.addColumn(subscriptions, subscriptions.channelGroupPrefix);
        await m.createTable(deadChannels);
      }
      if (from < 7) {
        // v7: 高频查询路径的索引（EPG 窗口查询、按订阅过滤频道、
        // 观看历史按频道聚合）。
        await _createIndexes();
      }
      if (from < 8) {
        // v8: persist the source-provided tvg-name channel metadata.
        await m.addColumn(channels, channels.tvgName);
      }
      if (from < 9) {
        // v9: 新增 scheduled_recordings（EPG 定时录制）。
        await m.createTable(scheduledRecordings);
      }
    },
  );

  /// Secondary indexes for the hot query paths. Idempotent, so it is
  /// safe to run from both [MigrationStrategy.onCreate] and
  /// [MigrationStrategy.onUpgrade].
  Future<void> _createIndexes() async {
    // programmesInWindow / programmesFor: stop > from AND start < to.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_epg_programmes_window '
      'ON epg_programmes (stop, start)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_epg_programmes_channel_start '
      'ON epg_programmes (channel_id, start)',
    );
    // watchAll / watchCountsBySubscription / replaceAll filter or join
    // channels by subscription.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_channels_subscription '
      'ON channels (subscription_id)',
    );
    // watchRecent: GROUP BY channel_key with MAX(watched_at).
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_watch_history_key_time '
      'ON watch_history (channel_key, watched_at)',
    );
  }

  static QueryExecutor _openOnDisk() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'zerotv.sqlite'));
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          // WAL lets the background-sync isolate's second connection read
          // concurrently with the foreground writer (writes are still
          // serialized — one writer at a time). busy_timeout makes a
          // colliding write wait briefly instead of failing with
          // SQLITE_BUSY right away.
          rawDb
            ..execute('PRAGMA journal_mode = WAL')
            ..execute('PRAGMA busy_timeout = 5000')
            ..execute('PRAGMA foreign_keys = ON');
        },
      );
    });
  }
}
