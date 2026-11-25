import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/types/side_played.dart';

class MemoryTutorialStore implements TutorialProgressStore {
  TutorialProgressData? saved;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;

  @override
  Future<TutorialProgressData?> read() async {
    if (failRead) throw StateError('keystore unavailable');
    return saved;
  }

  @override
  Future<void> write(TutorialProgressData data) async {
    if (failWrite) throw StateError('keystore unavailable');
    writes++;
    saved = data;
  }
}

class MemoryLegacyStore implements OnboardingStore {
  MemoryLegacyStore({this.completed = false, this.step});
  bool completed;
  int? step;
  int reads = 0;

  @override
  Future<bool> hasCompletedOnboarding() async {
    reads++;
    return completed;
  }

  @override
  Future<void> markOnboardingComplete() async => completed = true;
  @override
  Future<int?> readProgress() async => step;
  @override
  Future<void> saveProgress(int step) async => this.step = step;
}

void main() {
  group('TutorialProgressData', () {
    test('round-trips through its saved form', () {
      const data = TutorialProgressData(
        completed: {TutorialTrack.logSpin, TutorialTrack.addRecord},
        introSeen: true,
        goldCelebrated: true,
      );
      expect(TutorialProgressData.fromJson(data.toJson()), data);
    });

    test('ignores unknown tracks and damaged values instead of losing all', () {
      final data = TutorialProgressData.fromJson(
        '{"completed":["stats","fromTheFuture",3],"introSeen":"yes"}',
      );
      expect(data.completed, {TutorialTrack.stats});
      expect(data.introSeen, isFalse);
      expect(
        TutorialProgressData.fromJson('not json'),
        const TutorialProgressData(),
      );
    });

    test('track names are stable because they are what gets saved', () {
      expect(TutorialTrack.values.map((t) => t.name), [
        'addRecord',
        'logSpin',
        'stats',
        'nfc',
        'swipe',
        'backup',
        'discogsImport',
      ]);
    });
  });

  group('migration from the old walkthrough', () {
    test('someone who finished or started it has seen the intro', () async {
      expect(
        (await migrateFromWalkthrough(
          MemoryLegacyStore(completed: true),
        )).introSeen,
        isTrue,
      );
      expect(
        (await migrateFromWalkthrough(MemoryLegacyStore(step: 3))).introSeen,
        isTrue,
      );
    });

    test(
      'a fresh install has not, and no tracks come from old steps',
      () async {
        final fresh = await migrateFromWalkthrough(MemoryLegacyStore());
        expect(fresh.introSeen, isFalse);
        final midway = await migrateFromWalkthrough(MemoryLegacyStore(step: 6));
        expect(midway.completed, isEmpty);
      },
    );
  });

  test('the secure store saves and reads progress', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureTutorialProgressStore(FlutterSecureStorage());
    expect(await store.read(), isNull);
    const data = TutorialProgressData(
      completed: {TutorialTrack.swipe},
      introSeen: true,
    );
    await store.write(data);
    expect(await store.read(), data);
  });

  group('TutorialProgressController', () {
    late AppDatabase db;
    late MemoryTutorialStore store;
    late MemoryLegacyStore legacy;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = MemoryTutorialStore();
      legacy = MemoryLegacyStore();
    });
    tearDown(() => db.close());

    ProviderContainer container({bool nfc = true, bool backup = false}) {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tutorialProgressStoreProvider.overrideWithValue(store),
          onboardingStoreProvider.overrideWithValue(legacy),
          nfcHelpVisibleProvider.overrideWithValue(nfc),
          backupTrackAvailableProvider.overrideWithValue(backup),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<TutorialView> view(ProviderContainer c) async {
      await c.read(tutorialProgressProvider.future);
      await c.read(tutorialProgressProvider.notifier).settled;
      return c.read(tutorialViewProvider).requireValue;
    }

    Future<void> addRecord(
      String id, {
      bool play = false,
      bool tag = false,
    }) async {
      await db
          .into(db.artists)
          .insertOnConflictUpdate(
            const Artist(
              id: 'artist-1',
              name: 'Nina Simone',
              createdAt: '2026-01-01',
            ),
          );
      await db
          .into(db.albums)
          .insert(
            Album(
              id: id,
              title: 'Record $id',
              artistId: 'artist-1',
              createdAt: '2026-01-01',
            ),
          );
      if (play) {
        await db
            .into(db.plays)
            .insert(
              Play(
                id: 'play-$id',
                albumId: id,
                playedAt: '2026-02-01',
                sidePlayed: SidePlayed.full,
                createdAt: '2026-02-01',
              ),
            );
      }
      if (tag) {
        await db
            .into(db.nfcTags)
            .insert(
              NfcTag(
                id: 'nfc-$id',
                albumId: id,
                nfcTagId: 'TAG-$id',
                writtenAt: '2026-02-01',
              ),
            );
      }
    }

    test('a fresh shelf: one record needed, record tracks locked', () async {
      final v = await view(container());
      expect(v.introSeen, isFalse);
      expect(v.badges, isEmpty);
      expect(
        v.statusOf(TutorialTrack.addRecord),
        TutorialTrackStatus.available,
      );
      expect(v.statusOf(TutorialTrack.stats), TutorialTrackStatus.available);
      for (final t in [
        TutorialTrack.logSpin,
        TutorialTrack.nfc,
        TutorialTrack.swipe,
      ]) {
        expect(v.statusOf(t), TutorialTrackStatus.locked, reason: t.name);
      }
      expect(v.next, TutorialTrack.addRecord);
    });

    test(
      'an imported or existing shelf lights up what is already done',
      () async {
        await addRecord('album-1', play: true, tag: true);
        final c = container();
        final v = await view(c);
        expect(v.badges, [
          TutorialTrack.addRecord,
          TutorialTrack.logSpin,
          TutorialTrack.nfc,
        ]);
        expect(v.statusOf(TutorialTrack.swipe), TutorialTrackStatus.available);
        expect(v.next, TutorialTrack.stats);
        expect(store.saved!.completed, containsAll(v.badges));
      },
    );

    test(
      'refreshing after an import unlocks tracks and keeps badges',
      () async {
        final c = container();
        await view(c);
        await addRecord('album-1', play: true);
        await c.read(tutorialProgressProvider.notifier).refreshEvidence();
        var v = await view(c);
        expect(v.statusOf(TutorialTrack.swipe), TutorialTrackStatus.available);
        expect(v.badges, [TutorialTrack.addRecord, TutorialTrack.logSpin]);

        // Deleting every record later doesn't take badges away.
        await db.delete(db.albums).go();
        await c.read(tutorialProgressProvider.notifier).refreshEvidence();
        v = await view(c);
        expect(v.hasRecord, isFalse);
        expect(v.badges, [TutorialTrack.addRecord, TutorialTrack.logSpin]);
        expect(v.statusOf(TutorialTrack.swipe), TutorialTrackStatus.locked);
      },
    );

    test(
      'playing tracks earns badges and gold needs only required ones',
      () async {
        await addRecord('album-1', play: true);
        final c = container(backup: true);
        final notifier = c.read(tutorialProgressProvider.notifier);
        await view(c);
        await notifier.complete(TutorialTrack.stats);
        await notifier.complete(TutorialTrack.swipe);
        var v = await view(c);
        expect(v.required, [
          TutorialTrack.addRecord,
          TutorialTrack.logSpin,
          TutorialTrack.stats,
          TutorialTrack.swipe,
          TutorialTrack.backup,
        ]);
        expect(v.isGold, isFalse);
        // Tracks are offered in order, so NFC (Track 4) comes before Backup
        // (Track 6) even though it's optional.
        expect(v.next, TutorialTrack.nfc);
        expect(v.nextAfter(TutorialTrack.nfc), TutorialTrack.backup);

        await notifier.complete(TutorialTrack.backup);
        v = await view(c);
        expect(v.requiredDone, 5);
        expect(v.isGold, isTrue, reason: 'NFC and Discogs are optional');
        expect(v.next, TutorialTrack.nfc, reason: 'still offered after gold');

        await notifier.markGoldCelebrated();
        await notifier.settled;
        expect(store.saved!.goldCelebrated, isTrue);
      },
    );

    test('NFC is offered right after Stats, Discogs only at the end', () async {
      await addRecord('album-1', play: true);
      final c = container(backup: true);
      final notifier = c.read(tutorialProgressProvider.notifier);
      await view(c);
      await notifier.complete(TutorialTrack.stats);
      var v = await view(c);
      expect(v.next, TutorialTrack.nfc);

      for (final track in [
        TutorialTrack.nfc,
        TutorialTrack.swipe,
        TutorialTrack.backup,
      ]) {
        await notifier.complete(track);
      }
      v = await view(c);
      expect(v.next, TutorialTrack.discogsImport);
    });

    test('skipping suggests a different track, later ones first', () async {
      await addRecord('album-1');
      final v = await view(container(backup: true));
      expect(v.nextAfter(TutorialTrack.logSpin), TutorialTrack.stats);
      expect(v.nextAfter(TutorialTrack.backup), TutorialTrack.logSpin);
      expect(v.nextAfter(TutorialTrack.stats), isNot(TutorialTrack.stats));
    });

    test(
      'NFC is hidden on phones without NFC; backup until it ships',
      () async {
        final v = await view(container(nfc: false));
        expect(v.tracks, isNot(contains(TutorialTrack.nfc)));
        expect(v.tracks, isNot(contains(TutorialTrack.backup)));
        expect(v.required, [
          TutorialTrack.addRecord,
          TutorialTrack.logSpin,
          TutorialTrack.stats,
          TutorialTrack.swipe,
        ]);
      },
    );

    test('saved progress is used as-is, without migrating again', () async {
      store.saved = const TutorialProgressData(
        completed: {TutorialTrack.stats},
        introSeen: true,
      );
      final v = await view(container());
      expect(legacy.reads, 0);
      expect(v.introSeen, isTrue);
      expect(v.badges, [TutorialTrack.stats]);
    });

    test('first run migrates once and saves the result', () async {
      legacy.completed = true;
      final v = await view(container());
      expect(v.introSeen, isTrue);
      expect(store.saved?.introSeen, isTrue);
    });

    test(
      'unreadable storage never blocks: no intro, progress in memory',
      () async {
        store.failRead = true;
        store.failWrite = true;
        await addRecord('album-1');
        final c = container();
        var v = await view(c);
        expect(v.introSeen, isTrue);
        expect(v.badges, [TutorialTrack.addRecord]);
        await c
            .read(tutorialProgressProvider.notifier)
            .complete(TutorialTrack.stats);
        v = await view(c);
        expect(v.badges, [TutorialTrack.addRecord, TutorialTrack.stats]);
      },
    );

    test('completing a track twice saves once', () async {
      final c = container();
      final notifier = c.read(tutorialProgressProvider.notifier);
      await view(c);
      final before = store.writes;
      await notifier.complete(TutorialTrack.stats);
      await notifier.complete(TutorialTrack.stats);
      await notifier.settled;
      expect(store.writes, before + 1);
    });
  });
}
