import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zerotv_player/features/player/application/playback_session.dart';

import 'fixtures/live_video_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('non-seekable live video stays visible without false failure', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final fixture = await LiveVideoFixture.start();
    final player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.info),
    );
    final controller = VideoController(player);
    final session = PlaybackSession(
      sources: [Channel(name: 'Live test', streamUrl: fixture.url)],
      open: (channel) => player.open(Media(channel.streamUrl)),
    );
    final errors = <String>[];
    final errorSub = player.stream.error.listen((message) {
      errors.add(message);
      session.onError(message);
    });
    final logSub = player.stream.log.listen((log) => debugPrint('$log'));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Video(
                controller: controller,
                controls: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await (player.platform! as NativePlayer).setProperty(
          'demuxer-seekable-cache',
          'no',
        );
        await session.start();
        await controller.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 20),
        );
        await player.seek(const Duration(seconds: 60));
      });
      await tester.pump(const Duration(seconds: 2));
      expect(session.error, isNull, reason: errors.join('\n'));
      expect(errors.any((error) => error.contains('force-seekable')), isTrue);
      expect(session.index, 0);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump(const Duration(seconds: 1));
      final screenshot = await binding.takeScreenshot(
        'non-seekable-live-video',
      );
      await _expectRedCenter(screenshot);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await errorSub.cancel();
      await logSub.cancel();
      session.dispose();
      await player.dispose();
      await fixture.close();
    }
  });
}

Future<void> _expectRedCenter(List<int> screenshot) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(screenshot));
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final pixels = (await image.toByteData())!;
  final offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
  final red = pixels.getUint8(offset);
  final green = pixels.getUint8(offset + 1);
  final blue = pixels.getUint8(offset + 2);
  image.dispose();
  codec.dispose();
  expect(red, greaterThan(150), reason: 'Video center RGB: $red,$green,$blue');
  expect(green, lessThan(100));
  expect(blue, lessThan(100));
}
