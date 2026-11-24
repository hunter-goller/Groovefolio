import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_target.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/track_scripts.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/routing/router.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

import '../../../support/tutorial_test_support.dart';
import 'tutorial_progress_test.dart' show MemoryLegacyStore;

/// Plays the Side A tracks in the real app, through the real router and
/// screens, to prove each step points at a control that exists and moves on.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> seed() async {
    await db
        .into(db.artists)
        .insert(
          const Artist(
            id: 'artist-1',
            name: 'Miles Davis',
            createdAt: '2026-01-01',
          ),
        );
    for (final (id, title) in [
      ('album-1', 'Kind of Blue'),
      ('album-2', 'Sketches'),
    ]) {
      await db
          .into(db.albums)
          .insert(
            Album(
              id: id,
              title: title,
              artistId: 'artist-1',
              createdAt: '2026-01-01',
            ),
          );
    }
    await db
        .into(db.plays)
        .insert(
          const Play(
            id: 'play-1',
            albumId: 'album-1',
            playedAt: '2026-11-20T20:00:00',
            sidePlayed: SidePlayed.full,
            createdAt: '2026-11-20T20:00:00',
          ),
        );
  }

  Future<void> settle(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pumpApp(WidgetTester tester, {bool records = true}) async {
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (records) await tester.runAsync(seed);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        skipTutorialWelcome(),
        onboardingStoreProvider.overrideWithValue(MemoryLegacyStore()),
        nfcHelpVisibleProvider.overrideWithValue(false),
        discogsAccountProvider.overrideWithValue(
          const AsyncData<DiscogsAccount?>(null),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: ref.watch(routerProvider),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  TutorialSession session() => container.read(tutorialSessionProvider.notifier);
  TutorialSessionState state() => container.read(tutorialSessionProvider);
  GoRouter router() => container.read(routerProvider);
  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('spotlight-title'))).data!;
  Rect rectOf(SpotlightId id) =>
      container.read(spotlightRegistryProvider).rectOf(id)!;

  testWidgets('Track 1 by hand: dim blocks, the real button moves on', (
    tester,
  ) async {
    await pumpApp(tester);
    session().play(TutorialTrack.addRecord);
    await settle(tester);
    expect(title(tester), 'Add your first record');

    // Taps outside the spotlight are absorbed: no record opens.
    await tester.tapAt(const Offset(40, 300));
    await settle(tester, 3);
    expect(router().state.uri.path, '/');
    expect(state().step, 0);

    await tester.tapAt(rectOf(SpotlightId.addRecordFab).center);
    await settle(tester);
    expect(router().state.uri.path, '/album/new');
    expect(title(tester), 'Type the album title');

    await tester.tap(find.byKey(const Key('add-record-title')));
    await settle(tester);
    expect(title(tester), 'Add the artist');
    await tester.tap(find.byKey(const Key('add-record-artist')));
    await settle(tester);
    expect(title(tester), 'Tap Save');
    await finish(tester);
  });

  testWidgets('Track 1 skips "Tap Add record" if you are already there', (
    tester,
  ) async {
    await pumpApp(tester);
    session().play(TutorialTrack.addRecord);
    unawaited(router().push('/album/new'));
    await settle(tester);
    expect(state().step, 1);
    expect(title(tester), 'Type the album title');
    await finish(tester);
  });

  testWidgets('Track 1 via Discogs offers "Add by hand instead"', (
    tester,
  ) async {
    await pumpApp(tester, records: false);
    session().play(TutorialTrack.addRecord, path: ShelfPath.discogs);
    unawaited(router().push('/settings'));
    await settle(tester);
    expect(title(tester), 'Connect Discogs');

    await tester.tap(find.byKey(const Key('spotlight-by-hand')));
    await settle(tester);
    expect(state().path, ShelfPath.byHand);
    expect(router().state.uri.path, '/');
    expect(title(tester), 'Add your first record');
    await finish(tester);
  });

  testWidgets('Track 2: pick a record, then the side', (tester) async {
    await pumpApp(tester);
    session().play(TutorialTrack.logSpin);
    unawaited(router().push('/play/log'));
    await settle(tester);
    expect(title(tester), 'Pick a record');
    await tester.tapAt(rectOf(SpotlightId.logPickRecord).center);
    await settle(tester);
    expect(title(tester), 'Which side?');
    await finish(tester);
  });

  testWidgets('Track 3: Got it, then Discover finishes the track', (
    tester,
  ) async {
    await pumpApp(tester);
    session().play(TutorialTrack.stats);
    router().go('/stats');
    await settle(tester);
    expect(title(tester), 'Your listening, at a glance');
    // A look-only step waits for Got it, even though Discover is visible.
    await settle(tester, 4);
    expect(state().step, 0);

    await tester.tap(find.byKey(const Key('spotlight-got-it')));
    await settle(tester);
    expect(title(tester), 'Now tap Discover');
    // The tab's label is inside the spotlight too.
    await tester.tap(find.text('Discover'));
    await settle(tester);
    expect(router().state.uri.path, '/discover');
    expect(find.text('TRACK 3 COMPLETE'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('off track: no dimming, and Show me goes back', (tester) async {
    await pumpApp(tester);
    session().play(TutorialTrack.logSpin);
    await settle(tester);
    expect(find.byKey(const Key('spotlight-show-me')), findsOneWidget);
    // Nothing is blocked while off track.
    await tester.tap(find.text('Sketches'));
    await settle(tester);
    expect(router().state.uri.path, startsWith('/album/'));

    await tester.tap(find.byKey(const Key('spotlight-show-me')));
    await settle(tester);
    expect(router().state.uri.path, '/play/log');
    expect(title(tester), 'Pick a record');
    await finish(tester);
  });

  testWidgets('Pause ends the track; Skip moves to the next one', (
    tester,
  ) async {
    await pumpApp(tester);
    session().play(TutorialTrack.stats);
    router().go('/stats');
    await settle(tester);
    await tester.tap(find.byKey(const Key('spotlight-pause')));
    await settle(tester);
    expect(state().active, isNull);
    expect(find.byKey(const Key('spotlight-title')), findsNothing);

    session().play(TutorialTrack.stats);
    await settle(tester);
    await tester.tap(find.byKey(const Key('spotlight-skip')));
    await settle(tester);
    expect(state().active, TutorialTrack.swipe, reason: 'next playable track');
    await finish(tester);
  });

  testWidgets('reduced motion: the hand stays still', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);
    session().play(TutorialTrack.addRecord);
    await settle(tester);
    expect(title(tester), 'Add your first record');
    expect(tester.binding.hasScheduledFrame, isFalse);
    await finish(tester);
  });

  group('session rules', () {
    test('taps only move on the current tap step', () {
      final c = ProviderContainer(
        overrides: [
          tutorialProgressStoreProvider.overrideWithValue(
            IntroSeenTutorialStore(),
          ),
        ],
      );
      addTearDown(c.dispose);
      final s = c.read(tutorialSessionProvider.notifier)
        ..play(TutorialTrack.stats)
        ..targetTapped(SpotlightId.statsSummary);
      expect(c.read(tutorialSessionProvider).step, 0, reason: 'Got it step');
      s.advance();
      s.targetTapped(SpotlightId.addTitle);
      expect(c.read(tutorialSessionProvider).step, 1, reason: 'wrong control');
      s.jumpTo(0);
      expect(
        c.read(tutorialSessionProvider).step,
        1,
        reason: 'never backwards',
      );
    });
  });
}
