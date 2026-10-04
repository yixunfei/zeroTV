import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled native player decodes local PCM audio', (tester) async {
    MediaKit.ensureInitialized();
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('zerotv_smoke_');
      final file = File('${directory.path}/sample.wav');
      await file.writeAsBytes(_wave());
      final player = Player();
      try {
        final playing = player.stream.playing.firstWhere((value) => value);
        await player.open(Media(file.uri.toString()));
        await playing.timeout(const Duration(seconds: 15));
        final position = await player.stream.position
            .firstWhere((value) => value > const Duration(milliseconds: 100))
            .timeout(const Duration(seconds: 15));
        expect(position, greaterThan(const Duration(milliseconds: 100)));
      } finally {
        await player.dispose();
        await directory.delete(recursive: true);
      }
    });
  });
}

Uint8List _wave() {
  const rate = 8000;
  const bytes = rate * 2 * 3;
  final data = ByteData(44 + bytes);
  void tag(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + bytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, bytes, Endian.little);
  return data.buffer.asUint8List();
}
