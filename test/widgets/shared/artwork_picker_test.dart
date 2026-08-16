import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/shared/artwork_picker.dart';

void main() {
  testWidgets('shows add-art placeholder and forwards taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ArtworkPicker(image: null, onTap: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Add art'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);

    await tester.tap(find.byType(ArtworkPicker));
    expect(tapped, isTrue);
  });

  testWidgets('shows selected image and edit affordance', (tester) async {
    // The widget only needs an existing File so its selected-artwork branch is
    // active. The injected imageBuilder never reads or decodes this file.
    //
    // Avoid Directory.systemTemp/createTemp here: on some Windows Flutter test
    // runners that call can block during test isolation/finalization.
    final image = File(Platform.resolvedExecutable);

    final imageExists = image.existsSync();
    expect(imageExists, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ArtworkPicker(
            image: image,
            onTap: () {},
            imageBuilder: (file) {
              return const ColoredBox(
                key: Key('test-artwork-image'),
                color: Colors.black,
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('test-artwork-image')), findsOneWidget);

    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

    expect(find.text('Add art'), findsNothing);
  });

  testWidgets('disabled picker does not forward taps', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ArtworkPicker(image: null, enabled: false, onTap: () => taps++),
        ),
      ),
    );

    await tester.tap(find.byType(ArtworkPicker));
    expect(taps, 0);
  });

  testWidgets('respects requested size without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ArtworkPicker(image: null, size: 72, height: 96, onTap: () {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final box = tester.getSize(find.byType(ArtworkPicker));
    expect(box.width, 72);
    expect(box.height, 96);
  });
}
