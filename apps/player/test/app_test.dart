import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotv_player/app.dart';
import 'package:zerotv_player/core/database/app_database.dart';
import 'package:zerotv_player/core/database/database_provider.dart';

void main() {
  /// Pumps the app with an isolated in-memory database, closed on teardown.
  Future<void> pumpTestApp(WidgetTester tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const ZeroTvApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('app shell renders the channel list empty state', (tester) async {
    await pumpTestApp(tester);

    expect(find.text('zeroTV'), findsOneWidget);
    expect(find.text('还没有任何频道'), findsOneWidget);
    expect(find.text('添加订阅'), findsOneWidget);
  });

  testWidgets('settings page opens from the app bar', (tester) async {
    await pumpTestApp(tester);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('订阅同步'), findsOneWidget);
    expect(find.text('关于 zeroTV'), findsOneWidget);
  });
}
