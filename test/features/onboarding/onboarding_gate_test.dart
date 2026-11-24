import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';
import 'package:vinyl_app/features/onboarding/widgets/onboarding_gate.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

import 'tracks/tutorial_progress_test.dart'
    show MemoryLegacyStore, MemoryTutorialStore;

void main() {
  Future<void> pumpGate(
    WidgetTester tester, {
    int records = 0,
    TutorialProgressData? saved,
    bool failRead = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryTutorialStore()
      ..saved = saved
      ..failRead = failRead;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tutorialProgressStoreProvider.overrideWithValue(store),
          onboardingStoreProvider.overrideWithValue(MemoryLegacyStore()),
          nfcHelpVisibleProvider.overrideWithValue(false),
          tutorialEvidenceReaderProvider.overrideWithValue(
            () async =>
                TutorialEvidence(records: records, plays: 0, nfcTags: 0),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingGate(child: Text('Collection test')),
        ),
      ),
    );
    // The welcome vinyl spins, so pump a few frames instead of settling.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a fresh install is welcomed', (tester) async {
    await pumpGate(tester);
    expect(find.text('Drop the needle'), findsOneWidget);
    expect(find.text('Collection test'), findsNothing);
  });

  testWidgets('someone who has seen the intro goes straight in', (
    tester,
  ) async {
    await pumpGate(tester, saved: const TutorialProgressData(introSeen: true));
    expect(find.text('Collection test'), findsOneWidget);
  });

  testWidgets('a shelf with records goes straight in', (tester) async {
    await pumpGate(tester, records: 3);
    expect(find.text('Collection test'), findsOneWidget);
    expect(find.text('Drop the needle'), findsNothing);
  });

  testWidgets('unreadable progress opens the collection', (tester) async {
    await pumpGate(tester, failRead: true);
    expect(find.text('Collection test'), findsOneWidget);
    expect(find.textContaining('keystore'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
