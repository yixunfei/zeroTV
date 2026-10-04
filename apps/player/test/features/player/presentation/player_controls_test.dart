import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/player/presentation/player_controls.dart';
import 'package:zerotv_player/features/player/presentation/player_history_panel.dart';

import '../../../helpers/localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('top controls collapse secondary actions on narrow screens', (
    tester,
  ) async {
    var menuOpened = false;
    var catchupOpened = false;
    await tester.binding.setSurfaceSize(const Size(390, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      localizedApp(
        home: PlayerTopControls(
          title: 'News',
          subtitle: 'Now playing',
          inCatchup: false,
          isLandscape: false,
          onBack: () {},
          onReturnToLive: () {},
          onToggleOrientation: () {},
          onToggleLock: () {},
          onMenuVisibilityChanged: (visible) => menuOpened = visible,
          onShowSources: () {},
          onShowCatchup: () => catchupOpened = true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('player-navigation-menu')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('player-navigation-menu')));
    await tester.pumpAndSettle();

    expect(find.text('回看'), findsOneWidget);
    expect(menuOpened, isTrue);
    final menuContext = tester.element(find.text('回看'));
    expect(Theme.of(menuContext).brightness, Brightness.dark);
    await tester.tap(find.text('回看'));
    await tester.pumpAndSettle();
    expect(menuOpened, isFalse);
    expect(catchupOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top controls collapse actions when text is enlarged', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      localizedApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: PlayerTopControls(
            title: 'News',
            inCatchup: false,
            isLandscape: false,
            onBack: () {},
            onReturnToLive: () {},
            onToggleOrientation: () {},
            onToggleLock: () {},
            onMenuVisibilityChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('player-navigation-menu')),
      findsOneWidget,
    );
  });

  testWidgets('history panel shows date, programme time and selected state', (
    tester,
  ) async {
    EpgProgram? picked;
    var closed = false;
    final programme = EpgProgram(
      channelId: 'news',
      title: 'Evening News',
      start: DateTime.utc(2026, 9, 27, 18),
      stop: DateTime.utc(2026, 9, 27, 19),
    );

    await tester.pumpWidget(
      localizedApp(
        home: SizedBox(
          width: 360,
          child: PlayerHistoryPanel(
            programmes: Future.value([programme]),
            selected: programme,
            onClose: () => closed = true,
            onSelected: (value) async => picked = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evening News'), findsOneWidget);
    final localStart = TimeOfDay.fromDateTime(
      programme.start.toLocal(),
    ).format(tester.element(find.text('Evening News')));
    expect(find.textContaining(localStart), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Evening News'));
    expect(picked, same(programme));
    await tester.tap(find.byTooltip('关闭'));
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(1280, 720),
  ]) {
    testWidgets('transport fits $size and keeps primary actions reachable', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var played = false;
      var recorded = false;
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PlayerTransportControls(
                playButton: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Play',
                  onPressed: () => played = true,
                ),
                recordButton: IconButton(
                  icon: const Icon(Icons.fiber_manual_record),
                  tooltip: 'Record',
                  onPressed: () => recorded = true,
                ),
                volumeControl: Row(
                  children: [
                    const Icon(Icons.volume_up),
                    Expanded(child: Slider(value: .5, onChanged: (_) {})),
                  ],
                ),
                secondaryControls: [
                  for (final label in ['Audio', 'Subtitle', 'Aspect', 'Speed'])
                    IconButton(
                      icon: const Icon(Icons.settings),
                      tooltip: label,
                      onPressed: () {},
                    ),
                ],
                moreButton: IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'More',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byTooltip('More'),
        size.width < 720 ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.byTooltip('Play'));
      await tester.tap(find.byTooltip('Record'));
      expect(played && recorded, isTrue);
    });
  }
}
