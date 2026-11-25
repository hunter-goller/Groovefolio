import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/badge_shelf_card.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_visuals.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/app_theme.dart';

import '../../../support/tutorial_test_support.dart';

void main() {
  Future<void> pump(WidgetTester tester, Set<TutorialTrack> completed) async {
    final store = IntroSeenTutorialStore()
      ..saved = TutorialProgressData(introSeen: true, completed: completed);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: BadgeShelfCard()),
        ),
        GoRoute(
          path: AppRoutes.tutorial,
          builder: (_, _) => const Scaffold(body: Text('Getting started')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tutorialProgressStoreProvider.overrideWithValue(store),
          tutorialEvidenceReaderProvider.overrideWithValue(
            () async => TutorialEvidence.none,
          ),
          nfcHelpVisibleProvider.overrideWithValue(true),
          backupTrackAvailableProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every badge with the earned count', (tester) async {
    final earned = {TutorialTrack.values[0], TutorialTrack.values[1]};
    await pump(tester, earned);

    final total = TutorialTrack.values.length;
    expect(find.text('Your badges'), findsOneWidget);
    expect(find.text('2 of $total'), findsOneWidget);
    final medals = tester.widgetList<BadgeMedal>(find.byType(BadgeMedal));
    expect(medals, hasLength(total));
    expect({
      for (final medal in medals)
        if (medal.earned) medal.track,
    }, earned);
  });

  testWidgets('nudges a newcomer to start', (tester) async {
    await pump(tester, const {});
    expect(
      find.text('Learn Groovefolio in a few short tracks and earn badges.'),
      findsOneWidget,
    );
  });

  testWidgets('opens Getting started when tapped', (tester) async {
    await pump(tester, const {});
    await tester.tap(find.byKey(const Key('stats-badges')));
    await tester.pumpAndSettle();
    expect(find.text('Getting started'), findsOneWidget);
  });
}
