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
}
