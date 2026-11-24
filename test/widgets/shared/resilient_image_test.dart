import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/shared/resilient_image.dart';

void main() {
  testWidgets('decode failure shows the local fallback without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ResilientImage.memory(
            bytes: Uint8List.fromList(const [0, 1, 2, 3]),
            operation: 'load test artwork',
            failureSemanticLabel: 'Test artwork unavailable',
            fallback: const ColoredBox(
              key: Key('artwork-fallback'),
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('artwork-fallback')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decodes artwork at the size of its box, not full size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: SizedBox.square(
            dimension: 58,
            child: ResilientImage.memory(
              bytes: Uint8List.fromList(const [0, 1, 2, 3]),
              operation: 'load test artwork',
              fallback: const SizedBox.shrink(),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image)).image;
    expect(image, isA<ResizeImage>());
    final resized = image as ResizeImage;
    // 58 logical px * 3 = 174 px, rounded up to a multiple of 64.
    expect(resized.width, 192);
    expect(resized.height, isNull);
    expect(resized.allowUpscaling, isFalse);
  });

  test('decode size uses the larger side and skips unbounded boxes', () {
    final source = MemoryImage(Uint8List.fromList(const [1]));

    final wide = decodeSizedImage(
      source,
      width: 142,
      height: 100,
      devicePixelRatio: 2,
    );
    expect((wide as ResizeImage).width, 320);

    expect(
      decodeSizedImage(
        source,
        width: double.infinity,
        height: double.infinity,
        devicePixelRatio: 2,
      ),
      same(source),
    );
  });

  test('tiles of nearby sizes share one decoded size', () {
    final source = MemoryImage(Uint8List.fromList(const [1]));
    final sizes = {
      for (final box in [52.0, 56.0, 58.0])
        (decodeSizedImage(source, width: box, height: box, devicePixelRatio: 3)
                as ResizeImage)
            .width,
    };
    expect(sizes, {192});
  });
}
