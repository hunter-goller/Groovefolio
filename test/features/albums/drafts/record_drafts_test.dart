import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/drafts/draft_resume_offer.dart';
import 'package:vinyl_app/features/albums/drafts/record_draft.dart';
import 'package:vinyl_app/features/albums/drafts/record_draft_keeper.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/features/albums/screens/edit_album_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/repositories/nfc_tag_repository.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

class MemoryDraftStore implements RecordDraftStore {
  final drafts = <RecordDraftKind, RecordDraft>{};
  int writes = 0;

  @override
  Future<RecordDraft?> read(RecordDraftKind kind) async => drafts[kind];

  @override
  Future<void> write(RecordDraftKind kind, RecordDraft draft) async {
    writes++;
    drafts[kind] = draft;
  }

  @override
  Future<void> delete(RecordDraftKind kind) async => drafts.remove(kind);
}

class _NoTags implements INfcTagRepository {
  @override
  Future<NfcTag?> findByAlbum(String albumId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _album = Album(
  id: 'album-1',
  title: 'Blue Train',
  artistId: 'artist-1',
  releaseYear: 1957,
  label: 'Blue Note',
  createdAt: '2026-08-14T00:00:00.000Z',
);
const _artist = Artist(
  id: 'artist-1',
  name: 'John Coltrane',
  createdAt: '2026-08-14T00:00:00.000Z',
);

void main() {
  group('RecordDraft', () {
    test('survives a round trip through JSON', () {
      final draft = RecordDraft(
        albumId: 'album-1',
        title: 'Homogenic',
        artist: 'Björk',
        year: '1997',
        label: 'One Little Indian',
        genres: const ['Electronic', 'Trip Hop'],
        artworkPath: '/tmp/cover.jpg',
        discogsReleaseId: 42,
        discogsTracks: const [
          DiscogsTrack(title: 'Hunter', sequence: 1, position: 'A1', side: 'A'),
          DiscogsTrack(title: 'Jóga', sequence: 2, durationSeconds: 305),
        ],
        nfc: true,
        savedAt: DateTime.utc(2026, 11, 25, 10),
      );
      final back = RecordDraft.fromJson(draft.toJson())!;
      expect(back.sameContentAs(draft), isTrue);
      expect(back.discogsTracks[1].durationSeconds, 305);
      expect(back.savedAt, DateTime.utc(2026, 11, 25, 10));
    });

    test('knows when nothing was entered and names itself', () {
      expect(const RecordDraft().isBlank, isTrue);
      expect(const RecordDraft(year: '1').isBlank, isFalse);
      expect(const RecordDraft(title: 'Blue Train').name, '“Blue Train”');
      expect(const RecordDraft(artist: 'Björk').name, '“Björk”');
      expect(const RecordDraft().name, 'a record');
    });

    test('ignores drafts from another version', () {
      expect(RecordDraft.fromJson({'version': 2, 'title': 'x'}), isNull);
      expect(RecordDraft.fromJson('nonsense'), isNull);
    });
  });

  group('FileRecordDraftStore', () {
    late Directory dir;
    late DateTime now;
    late FileRecordDraftStore store;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('drafts');
      now = DateTime.utc(2026, 11, 25);
      store = FileRecordDraftStore(directory: () async => dir, now: () => now);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes, reads and deletes each kind separately', () async {
      await store.write(
        RecordDraftKind.add,
        RecordDraft(title: 'Blue Train', savedAt: now),
      );
      await store.write(
        RecordDraftKind.edit,
        RecordDraft(albumId: 'a', title: 'Kind of Blue', savedAt: now),
      );
      expect((await store.read(RecordDraftKind.add))!.title, 'Blue Train');
      expect((await store.read(RecordDraftKind.edit))!.albumId, 'a');
      await store.delete(RecordDraftKind.add);
      expect(await store.read(RecordDraftKind.add), isNull);
      expect(await store.read(RecordDraftKind.edit), isNotNull);
    });

    test('drops drafts older than two weeks', () async {
      await store.write(
        RecordDraftKind.add,
        RecordDraft(title: 'Old', savedAt: now),
      );
      now = now.add(const Duration(days: 15));
      expect(await store.read(RecordDraftKind.add), isNull);
      expect(dir.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('a damaged file reads as no draft', () async {
      final file = File('${dir.path}/record_drafts/add.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{not json');
      expect(await store.read(RecordDraftKind.add), isNull);
      expect(file.existsSync(), isFalse);
    });
  });

  group('Add record', () {
    late MemoryDraftStore store;
    File? recovered;
    setUp(() {
      store = MemoryDraftStore();
      recovered = null;
    });

    Future<GoRouter> pumpAdd(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        initialLocation: AppRoutes.addAlbum,
        routes: [
          GoRoute(
            path: AppRoutes.collection,
            builder: (_, _) => const Scaffold(body: Text('Collection')),
          ),
          GoRoute(
            path: AppRoutes.addAlbum,
            builder: (_, _) => const AddRecordScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recordDraftStoreProvider.overrideWithValue(store),
            lostPickedImageProvider.overrideWithValue(() async => recovered),
            genresProvider.overrideWith((ref) async => const <Genre>[]),
            discogsAccountProvider.overrideWithValue(const AsyncData(null)),
            nfcAvailabilityProvider.overrideWithValue(
              const AsyncData(NfcAvailabilityState.unsupported),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('keeps what is typed, and saves when the app is hidden', (
      tester,
    ) async {
      await pumpAdd(tester);
      await tester.enterText(
        find.byKey(const Key('add-record-title')),
        'Blue Train',
      );
      await tester.pump();
      expect(store.drafts[RecordDraftKind.add]!.title, 'Blue Train');

      final before = store.writes;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(store.writes, greaterThan(before));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('fills a waiting draft back in and can discard it', (
      tester,
    ) async {
      store.drafts[RecordDraftKind.add] = const RecordDraft(
        title: 'Blue Train',
        artist: 'John Coltrane',
        year: '1957',
      );
      await pumpAdd(tester);

      String field(String key) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text;
      expect(field('add-record-title'), 'Blue Train');
      expect(field('add-record-artist'), 'John Coltrane');
      expect(field('add-record-year'), '1957');
      expect(find.text('We kept what you were adding.'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(field('add-record-title'), isEmpty);
      expect(store.drafts[RecordDraftKind.add], isNull);
    });

    testWidgets('uses a photo the picker returned while the app was closed', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('picked');
      addTearDown(() => dir.deleteSync(recursive: true));
      recovered = File('${dir.path}/cover.jpg')..writeAsBytesSync([1, 2, 3]);
      store.drafts[RecordDraftKind.add] = const RecordDraft(title: 'Ten');
      await pumpAdd(tester);
      expect(store.drafts[RecordDraftKind.add]!.artworkPath, recovered!.path);
    });

    testWidgets('leaving the screen normally drops the draft', (tester) async {
      final router = await pumpAdd(tester);
      await tester.enterText(
        find.byKey(const Key('add-record-title')),
        'Blue Train',
      );
      await tester.pump();
      expect(store.drafts[RecordDraftKind.add], isNotNull);

      router.go(AppRoutes.collection);
      await tester.pumpAndSettle();
      expect(store.drafts[RecordDraftKind.add], isNull);
    });
  });

  group('Edit record', () {
    late MemoryDraftStore store;
    setUp(() => store = MemoryDraftStore());

    Future<void> pumpEdit(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recordDraftStoreProvider.overrideWithValue(store),
            lostPickedImageProvider.overrideWithValue(() async => null),
            genresProvider.overrideWith((ref) async => const <Genre>[]),
            albumGenresProvider.overrideWith((ref, id) async => const []),
            albumDetailProvider.overrideWith(
              (ref, id) async => const AlbumDetailData(
                album: _album,
                artist: _artist,
                plays: [],
              ),
            ),
            nfcTagRepositoryProvider.overrideWithValue(_NoTags()),
            nfcAvailabilityProvider.overrideWithValue(
              const AsyncData(NfcAvailabilityState.unsupported),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const EditAlbumScreen(albumId: 'album-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('restores unsaved changes over the saved record', (
      tester,
    ) async {
      store.drafts[RecordDraftKind.edit] = const RecordDraft(
        albumId: 'album-1',
        title: 'Blue Train (Mono)',
        artist: 'John Coltrane',
        year: '1957',
        label: 'Blue Note',
      );
      await pumpEdit(tester);
      expect(find.text('Blue Train (Mono)'), findsOneWidget);
      expect(find.text('We kept your unsaved changes.'), findsOneWidget);
    });

    testWidgets('ignores a draft for a different record', (tester) async {
      store.drafts[RecordDraftKind.edit] = const RecordDraft(
        albumId: 'album-2',
        title: 'Something else',
      );
      await pumpEdit(tester);
      expect(find.text('Blue Train'), findsOneWidget);
      expect(find.text('Something else'), findsNothing);
    });

    testWidgets('opening without changes keeps no draft', (tester) async {
      await pumpEdit(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(store.drafts[RecordDraftKind.edit], isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });

  group('saving', () {
    testWidgets('a saved record leaves no draft behind', (tester) async {
      final store = MemoryDraftStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [recordDraftStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: _SaveHarness()),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Blue Train');
      await tester.pump();
      expect(store.drafts[RecordDraftKind.add], isNotNull);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(store.drafts[RecordDraftKind.add], isNull);

      await tester.enterText(find.byType(TextField), 'Blue Train 2');
      await tester.pump();
      expect(store.drafts[RecordDraftKind.add], isNull);
    });
  });

  group('offer to continue', () {
    setUp(resetRecordDraftOffer);

    Future<void> pumpHome(WidgetTester tester, MemoryDraftStore store) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const _OfferHarness()),
          GoRoute(
            path: AppRoutes.addAlbum,
            builder: (_, _) => const Scaffold(body: Text('Add screen')),
          ),
          GoRoute(
            path: AppRoutes.editAlbum,
            builder: (_, state) =>
                Scaffold(body: Text('Edit ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [recordDraftStoreProvider.overrideWithValue(store)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers an unfinished Add record and opens it', (tester) async {
      final store = MemoryDraftStore()
        ..drafts[RecordDraftKind.add] = const RecordDraft(title: 'Blue Train');
      await pumpHome(tester, store);
      expect(
        find.text('You were adding “Blue Train”. Pick up where you left off?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Add screen'), findsOneWidget);
    });

    testWidgets('offers an unfinished edit and opens that record', (
      tester,
    ) async {
      final store = MemoryDraftStore()
        ..drafts[RecordDraftKind.edit] = const RecordDraft(
          albumId: 'album-9',
          title: 'Kind of Blue',
        );
      await pumpHome(tester, store);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Edit album-9'), findsOneWidget);
    });

    testWidgets('says nothing without a draft, and only once', (tester) async {
      final store = MemoryDraftStore();
      await pumpHome(tester, store);
      expect(find.byKey(const Key('record-draft-offer')), findsNothing);

      store.drafts[RecordDraftKind.add] = const RecordDraft(title: 'Late');
      await pumpHome(tester, store);
      expect(find.byKey(const Key('record-draft-offer')), findsNothing);
    });
  });
}

class _SaveHarness extends ConsumerStatefulWidget {
  const _SaveHarness();

  @override
  ConsumerState<_SaveHarness> createState() => _SaveHarnessState();
}

class _SaveHarnessState extends ConsumerState<_SaveHarness>
    with RecordDraftKeeper<_SaveHarness> {
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    initDrafts();
    markDraftReady();
  }

  @override
  void dispose() {
    disposeDrafts();
    _title.dispose();
    super.dispose();
  }

  @override
  RecordDraftKind get draftKind => RecordDraftKind.add;
  @override
  Listenable get draftFields => _title;
  @override
  RecordDraft captureDraft() => RecordDraft(title: _title.text);
  @override
  void applyDraft(RecordDraft draft) => _title.text = draft.title;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(controller: _title),
        TextButton(onPressed: finishDraft, child: const Text('Save')),
      ],
    ),
  );
}

class _OfferHarness extends ConsumerStatefulWidget {
  const _OfferHarness();

  @override
  ConsumerState<_OfferHarness> createState() => _OfferHarnessState();
}

class _OfferHarnessState extends ConsumerState<_OfferHarness> {
  @override
  void initState() {
    super.initState();
    offerToResumeRecordDraft(context, ref);
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Collection'));
}
