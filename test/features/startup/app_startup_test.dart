import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/startup/app_startup.dart';

void main() {
  testWidgets('failed initialization retries once and opens the app', (
    tester,
  ) async {
    var attempts = 0;
    final ready = Completer<Widget>();
    await tester.pumpWidget(
      AppStartup(
        initialize: () async {
          attempts++;
          if (attempts == 1) throw StateError('private database path');
          return ready.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t open your collection'), findsOneWidget);
    expect(find.textContaining('private database path'), findsNothing);
    expect(find.textContaining('reinstalling'), findsOneWidget);
    final retry = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('startup-retry')),
        matching: find.byType(FilledButton),
      ),
    );
    retry.onPressed!();
    retry.onPressed!();
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete(const MaterialApp(home: Text('Collection ready')));
    await tester.pumpAndSettle();
    expect(find.text('Collection ready'), findsOneWidget);
    expect(find.byKey(const Key('startup-retry')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup error and retry remain usable with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      AppStartup(
        initialize: () async {
          throw StateError('private details');
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('startup-retry')));
    expect(tester.takeException(), isNull);
  });
}
