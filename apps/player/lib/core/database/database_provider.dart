import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotv_player/core/database/app_database.dart';

/// Provides the singleton [AppDatabase].
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
