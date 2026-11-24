import 'dart:async';
import 'dart:io';

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

  group('save a copy of my data', () {
    Future<Never> failOpen() async => throw StateError('private details');

    Finder saveButton() => find.byKey(const Key('startup-save-copy'));

    testWidgets('is not offered without a rescue handler', (tester) async {
      await tester.pumpWidget(AppStartup(initialize: failOpen));
      await tester.pumpAndSettle();
      expect(saveButton(), findsNothing);
    });

    testWidgets('saving blocks retry, then confirms the copy', (tester) async {
      var attempts = 0;
      final saving = Completer<bool>();
      await tester.pumpWidget(
        AppStartup(
          initialize: () async {
            attempts++;
            throw StateError('private details');
          },
          saveRescueCopy: () => saving.future,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('still on this phone'), findsOneWidget);

      await tester.tap(saveButton());
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);

      // Retry stays visible but must not reopen the database mid-copy.
      await tester.tap(find.byKey(const Key('startup-retry')));
      await tester.pump();
      expect(attempts, 1);

      saving.complete(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-copy-saved')), findsOneWidget);
      expect(find.text('Save a copy of my data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the save dialog changes nothing', (tester) async {
      await tester.pumpWidget(
        AppStartup(initialize: failOpen, saveRescueCopy: () async => false),
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-copy-saved')), findsNothing);
      expect(find.byKey(const Key('startup-copy-failed')), findsNothing);
    });

    testWidgets('a failed save says the data is still on the phone', (
      tester,
    ) async {
      await tester.pumpWidget(
        AppStartup(
          initialize: failOpen,
          saveRescueCopy: () async =>
              throw const FileSystemException('private path'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-copy-failed')), findsOneWidget);
      expect(find.textContaining('private path'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both actions stay reachable with large text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        AppStartup(initialize: failOpen, saveRescueCopy: () async => true),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startup-copy-saved')));
      expect(tester.takeException(), isNull);
    });
  });
}
