import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotv_player/features/channel/presentation/channel_logo.dart';

void main() {
  const headers = {
    'User-Agent': 'zeroTV-test/1.0',
    'Referer': 'https://source.example/',
  };

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// Unwraps the ResizeImage that Image.network builds around the
  /// NetworkImage when cacheWidth/cacheHeight are set.
  NetworkImage networkProviderOf(Image image) {
    var provider = image.image;
    if (provider is ResizeImage) {
      provider = provider.imageProvider;
    }
    return provider as NetworkImage;
  }

  testWidgets('passes the anti-hotlinking headers to Image.network', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ChannelLogo(
          logoUrl: 'http://example.com/logo.png',
          headers: headers,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(networkProviderOf(image).headers, headers);
  });

  testWidgets('defaults to an empty header map', (tester) async {
    await tester.pumpWidget(
      wrap(const ChannelLogo(logoUrl: 'http://example.com/logo.png')),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(networkProviderOf(image).headers, isEmpty);
  });

  testWidgets('null logo URL renders the fallback icon without an image', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ChannelLogo(logoUrl: null)));

    expect(find.byIcon(Icons.live_tv_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('empty logo URL renders the fallback icon', (tester) async {
    await tester.pumpWidget(
      wrap(const ChannelLogo(logoUrl: '', headers: headers)),
    );

    expect(find.byIcon(Icons.live_tv_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
