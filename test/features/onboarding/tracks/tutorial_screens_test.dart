import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/screens/gold_record_screen.dart';
import 'package:vinyl_app/features/onboarding/tracks/screens/tracklist_screen.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_overlay_host.dart';
import 'package:vinyl_app/features/onboarding/widgets/onboarding_gate.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

import 'tutorial_progress_test.dart'
    show MemoryLegacyStore, MemoryTutorialStore;

class _Harness {
  _Harness({this.records = 0, this.plays = 0, TutorialProgressData? saved})
    : store = MemoryTutorialStore()..saved = saved;

  int records;
  int plays;
  final MemoryTutorialStore store;
  late ProviderContainer container;
  late GoRouter router;

  List<Override> overrides() => [
    tutorialProgressStoreProvider.overrideWithValue(store),
    onboardingStoreProvider.overrideWithValue(MemoryLegacyStore()),
    nfcHelpVisibleProvider.overrideWithValue(false),
    tutorialEvidenceReaderProvider.overrideWithValue(
      () async => TutorialEvidence(records: records, plays: plays, nfcTags: 0),
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    String initial = AppRoutes.collection,
  }) async {
    Widget page(String name) => Scaffold(body: Center(child: Text(name)));
    router = GoRouter(
      initialLocation: initial,
      routes: [
        ShellRoute(
          builder: (context, state, child) => TutorialOverlayHost(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.collection,
              builder: (_, _) => OnboardingGate(child: page('Collection page')),
            ),
            GoRoute(
              path: AppRoutes.addAlbum,
              builder: (_, _) => page('Add page'),
            ),
            GoRoute(
              path: AppRoutes.logPlay,
              builder: (_, _) => page('Log page'),
            ),
            GoRoute(
              path: AppRoutes.stats,
              builder: (_, _) => page('Stats page'),
            ),
            GoRoute(
              path: AppRoutes.settings,
              builder: (_, _) => page('Settings page'),
            ),
            GoRoute(
              path: AppRoutes.tutorial,
              builder: (_, _) => const TracklistScreen(),
            ),
            GoRoute(
              path: AppRoutes.tutorialGold,
              builder: (_, _) => const GoldRecordScreen(),
            ),
          ],
        ),
      ],
    );
    container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await settle(tester);
  }

  /// Lets async provider work finish; the vinyl spins, so no pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String get path => router.state.uri.path;
  TutorialSessionState get session => container.read(tutorialSessionProvider);
}

void main() {
  setUp(() {
    // Keep tall screens in view without scrolling.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> tall(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('welcome', () {
    testWidgets('a fresh install is welcomed; a shelf with records is not', (
      tester,
    ) async {
      await tall(tester);
      final fresh = _Harness();
      await fresh.pump(tester);
      expect(find.text('Drop the needle'), findsOneWidget);
      expect(
        find.textContaining('Play through 4 quick tracks'),
        findsOneWidget,
      );

      final existing = _Harness(records: 3);
      await existing.pump(tester);
      expect(find.text('Collection page'), findsOneWidget);
      expect(find.text('Drop the needle'), findsNothing);
    });

    testWidgets('Skip marks the intro seen and opens the shelf', (
      tester,
    ) async {
      await tall(tester);
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('tutorial-welcome-skip')));
      await h.settle(tester);
      expect(find.text('Collection page'), findsOneWidget);
      await h.container.read(tutorialProgressProvider.notifier).settled;
      expect(h.store.saved!.introSeen, isTrue);
    });

    testWidgets(
      'Drop the needle asks how to fill the shelf, then plays Track 1',
      (tester) async {
        await tall(tester);
        final h = _Harness();
        await h.pump(tester);
        await tester.tap(find.byKey(const Key('tutorial-welcome-start')));
        await h.settle(tester);
        expect(
          find.text('How do you want to fill your shelf?'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('shelf-choice-by-hand')));
        await h.settle(tester);
        expect(h.path, AppRoutes.collection);
        expect(h.session.active, TutorialTrack.addRecord);
        expect(find.text('Add your first record'), findsWidgets);
        expect(h.store.saved!.introSeen, isTrue);
      },
    );

    testWidgets('choosing Discogs goes to Settings to connect', (tester) async {
      await tall(tester);
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('tutorial-welcome-start')));
      await h.settle(tester);
      await tester.tap(find.byKey(const Key('shelf-choice-discogs')));
      await h.settle(tester);
      expect(h.path, AppRoutes.settings);
      expect(h.session.active, TutorialTrack.addRecord);
    });

    testWidgets('dismissing the choice changes nothing', (tester) async {
      await tall(tester);
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('tutorial-welcome-start')));
      await h.settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await h.settle(tester);
      expect(h.session.active, isNull);
      expect(find.text('Drop the needle'), findsOneWidget);
    });
  });

  group('tracklist', () {
    testWidgets('shows locks, the next track and plays any track', (
      tester,
    ) async {
      await tall(tester);
      final h = _Harness(saved: const TutorialProgressData(introSeen: true));
      await h.pump(tester, initial: AppRoutes.tutorial);
      expect(find.text('0 of 4 tracks'), findsOneWidget);
      expect(find.text('Add a record first'), findsWidgets);
      expect(find.byKey(const Key('track-play-logSpin')), findsNothing);
      expect(
        find.byKey(const Key('track-nfc')),
        findsNothing,
        reason: 'no NFC',
      );
      expect(find.byKey(const Key('track-backup')), findsNothing);

      await tester.tap(find.byKey(const Key('track-play-stats')));
      await h.settle(tester);
      expect(h.path, AppRoutes.stats);
      expect(h.session.active, TutorialTrack.stats);
    });

    testWidgets('completed tracks show their badge and can be replayed', (
      tester,
    ) async {
      await tall(tester);
      final h = _Harness(records: 2, plays: 1);
      await h.pump(tester, initial: AppRoutes.tutorial);
      expect(find.text('2 of 4 tracks'), findsOneWidget);
      expect(find.text('Badge: Crate Starter'), findsOneWidget);
      expect(find.text('Badge: First Spin'), findsOneWidget);
      expect(find.byTooltip('Replay Log a spin'), findsOneWidget);
      expect(find.text('YOUR BADGES · 2'), findsOneWidget);
    });
  });

  group('playing a track', () {
    testWidgets('finishing the active track celebrates with its badge', (
      tester,
    ) async {
      await tall(tester);
      final h = _Harness(
        records: 1,
        saved: const TutorialProgressData(introSeen: true),
      );
      await h.pump(tester);
      h.container
          .read(tutorialSessionProvider.notifier)
          .play(TutorialTrack.logSpin);
      await h.settle(tester);
      expect(find.byKey(const Key('spotlight-title')), findsOneWidget);

      h.plays = 1;
      await h.container
          .read(tutorialSessionProvider.notifier)
          .trackDone(TutorialTrack.logSpin);
      await h.settle(tester);
      expect(find.text('TRACK 2 COMPLETE'), findsOneWidget);
      expect(find.byKey(const Key('track-complete-badge')), findsOneWidget);
      expect(find.text('First Spin'), findsOneWidget);
      expect(find.byKey(const Key('spotlight-title')), findsNothing);

      await tester.tap(find.byKey(const Key('track-complete-shelf')));
      await h.settle(tester);
      expect(find.text('TRACK 2 COMPLETE'), findsNothing);
      expect(h.path, AppRoutes.collection);
    });

    testWidgets('doing it outside the tutorial earns the badge quietly', (
      tester,
    ) async {
      await tall(tester);
      final h = _Harness(saved: const TutorialProgressData(introSeen: true));
      await h.pump(tester);
      await h.container
          .read(tutorialSessionProvider.notifier)
          .trackDone(TutorialTrack.swipe);
      await h.settle(tester);
      expect(find.textContaining('COMPLETE'), findsNothing);
      expect(h.container.read(tutorialViewProvider).requireValue.badges, [
        TutorialTrack.swipe,
      ]);
    });

    testWidgets('Next plays the next track', (tester) async {
      await tall(tester);
      final h = _Harness(
        records: 1,
        plays: 1,
        saved: const TutorialProgressData(introSeen: true),
      );
      await h.pump(tester);
      final session = h.container.read(tutorialSessionProvider.notifier);
      session.play(TutorialTrack.swipe);
      await session.trackDone(TutorialTrack.swipe);
      await h.settle(tester);
      expect(find.text('Next: Check your stats'), findsOneWidget);
      await tester.tap(find.byKey(const Key('track-complete-next')));
      await h.settle(tester);
      expect(h.session.active, TutorialTrack.stats);
      expect(h.path, AppRoutes.stats);
    });

    testWidgets('Stats finishes on Discover, only after seeing Stats', (
      tester,
    ) async {
      final c = ProviderContainer(overrides: _Harness().overrides());
      addTearDown(c.dispose);
      final session = c.read(tutorialSessionProvider.notifier);
      await c.read(tutorialProgressProvider.future);
      session.play(TutorialTrack.stats);
      await session.discoverViewed();
      expect(c.read(tutorialSessionProvider).celebrating, isNull);
      session.statsViewed();
      await session.discoverViewed();
      expect(c.read(tutorialSessionProvider).celebrating, TutorialTrack.stats);
    });

    testWidgets('the last required track leads to the gold record', (
      tester,
    ) async {
      await tall(tester);
      final h = _Harness(
        records: 1,
        plays: 1,
        saved: const TutorialProgressData(
          introSeen: true,
          completed: {TutorialTrack.stats},
        ),
      );
      await h.pump(tester);
      final session = h.container.read(tutorialSessionProvider.notifier);
      session.play(TutorialTrack.swipe);
      await session.trackDone(TutorialTrack.swipe);
      await h.settle(tester);
      expect(find.text('See your gold record'), findsOneWidget);

      await tester.tap(find.byKey(const Key('track-complete-next')));
      await h.settle(tester);
      expect(h.path, AppRoutes.tutorialGold);
      expect(find.text('Gold record!'), findsOneWidget);
      await h.container.read(tutorialProgressProvider.notifier).settled;
      expect(h.store.saved!.goldCelebrated, isTrue);
    });

    testWidgets('gold record counts bonus badges separately', (tester) async {
      await tall(tester);
      final h = _Harness(
        records: 1,
        plays: 1,
        saved: const TutorialProgressData(
          introSeen: true,
          completed: {TutorialTrack.stats, TutorialTrack.discogsImport},
        ),
      );
      await h.pump(tester);
      final session = h.container.read(tutorialSessionProvider.notifier);
      session.play(TutorialTrack.swipe);
      await session.trackDone(TutorialTrack.swipe);
      await h.settle(tester);
      await tester.tap(find.byKey(const Key('track-complete-next')));
      await h.settle(tester);

      final summary = tester
          .widget<Text>(find.byKey(const Key('gold-record-summary')))
          .data!;
      expect(summary, contains('main tracks and a bonus one'));
      expect(find.text('Crate Digger'), findsOneWidget);
    });

    testWidgets('Stop ends the track without a badge', (tester) async {
      await tall(tester);
      final h = _Harness(saved: const TutorialProgressData(introSeen: true));
      await h.pump(tester);
      h.container
          .read(tutorialSessionProvider.notifier)
          .play(TutorialTrack.stats);
      await h.settle(tester);
      await tester.tap(find.byKey(const Key('spotlight-pause')));
      await h.settle(tester);
      expect(h.session.active, isNull);
      expect(find.byKey(const Key('spotlight-title')), findsNothing);
      expect(
        h.container.read(tutorialViewProvider).requireValue.badges,
        isEmpty,
      );
    });
  });
}
