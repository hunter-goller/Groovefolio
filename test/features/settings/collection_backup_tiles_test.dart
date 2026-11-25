import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/settings/widgets/collection_backup_tiles.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/backup/backup_file_gateway.dart';
import 'package:vinyl_app/services/backup/collection_backup_service.dart';
import 'package:vinyl_app/types/side_played.dart';

import '../../support/tutorial_test_support.dart';

class _FakeGateway implements BackupFileGateway {
  String? savedName;
  Uint8List? savedBytes;
  Uint8List? toOpen;
  int opens = 0;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    savedName = fileName;
    savedBytes = bytes;
    return true;
  }

  @override
  Future<Uint8List?> open() async {
    opens++;
    return toOpen;
  }
}

void main() {
  late Directory docs;
  late AppDatabase db;
  late CollectionBackupService service;
  late _FakeGateway gateway;
  late IntroSeenTutorialStore tutorial;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('groovefolio_backup_ui');
    db = AppDatabase(NativeDatabase.memory());
    service = CollectionBackupService(
      database: db,
      artworkStorage: ArtworkStorageService(
        documentsDirectoryResolver: () async => docs,
      ),
      clock: () => DateTime(2026, 11, 22),
    );
    gateway = _FakeGateway();
  });

  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
  });

  Future<void> seedOneRecord() async {
    await db
        .into(db.artists)
        .insert(
          const Artist(id: 'artist-1', name: 'Nina', createdAt: '2026-01-01'),
        );
    await db
        .into(db.albums)
        .insert(
          const Album(
            id: 'album-1',
            title: 'Pastel Blues',
            artistId: 'artist-1',
            createdAt: '2026-01-01',
          ),
        );
    await db
        .into(db.plays)
        .insert(
          const Play(
            id: 'play-1',
            albumId: 'album-1',
            playedAt: '2026-02-01',
            sidePlayed: SidePlayed.full,
            createdAt: '2026-02-01',
          ),
        );
  }

  Future<void> pump(WidgetTester tester) async {
    tutorial = IntroSeenTutorialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionBackupServiceProvider.overrideWithValue(service),
          backupFileGatewayProvider.overrideWithValue(gateway),
          tutorialProgressStoreProvider.overrideWithValue(tutorial),
          tutorialEvidenceReaderProvider.overrideWithValue(
            () async =>
                const TutorialEvidence(records: 1, plays: 1, nfcTags: 0),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CollectionBackupTiles())),
      ),
    );
  }

  testWidgets('Back up saves a dated backup file', (tester) async {
    await tester.runAsync(seedOneRecord);
    await pump(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('backup-collection')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(gateway.savedName, 'groovefolio-backup-2026-11-22.zip');
    final contents = service.readBackup(gateway.savedBytes!);
    expect(contents.summary.albums, 1);
    expect(contents.summary.plays, 1);
    expect(find.text('Backup saved. Keep it somewhere safe.'), findsOneWidget);
    // A real backup earns the tutorial's Safe Keeper badge quietly.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(tutorial.saved.completed, contains(TutorialTrack.backup));
  });

  testWidgets('Restore explains it needs an empty collection', (tester) async {
    await tester.runAsync(seedOneRecord);
    await pump(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('restore-collection')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Restore needs an empty collection'), findsOneWidget);
    expect(gateway.opens, 0);
  });

  testWidgets('Restore shows what is in the backup, then restores it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedOneRecord();
      gateway.toOpen = await service.createBackup();
      await db.delete(db.albums).go();
    });
    await pump(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('restore-collection')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Restore this backup?'), findsOneWidget);
    expect(
      find.textContaining('1 record, 1 play and 0 covers'),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-restore')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Restored 1 record and 1 play.'), findsOneWidget);
    final albums = await tester.runAsync(() => db.select(db.albums).get());
    expect(albums!.single.title, 'Pastel Blues');
  });

  testWidgets('Restore reports a file that is not a backup', (tester) async {
    gateway.toOpen = Uint8List.fromList([1, 2, 3]);
    await pump(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('restore-collection')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('That file isn’t a Groovefolio backup.'), findsOneWidget);
  });
}
