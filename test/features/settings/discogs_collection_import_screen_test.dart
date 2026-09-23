import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/settings/screens/discogs_collection_import_screen.dart';
import 'package:vinyl_app/services/discogs/discogs_collection_import_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/providers/album_providers.dart';

void main() {
  testWidgets(
    'interrupted import refreshes cached collection and retry reloads preview',
    (tester) async {
      final service = _InterruptedImportService();
      var reads = 0;
      var identities = 0;
      final container = ProviderContainer(
        overrides: [
          albumsProvider.overrideWith((ref) async {
            reads++;
            return [];
          }),
          discogsAccountProvider.overrideWith((ref) async {
            identities++;
            return const DiscogsAccount(id: 7, username: 'hunter');
          }),
          discogsCollectionImportServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        albumsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(albumsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const DiscogsCollectionImportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('discogs-import-selected-button')),
      );
      await tester.tap(find.byKey(const Key('discogs-import-selected-button')));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(
        find.textContaining('Records already imported are kept'),
        findsOneWidget,
      );
      expect(find.textContaining('private interrupted import'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(service.previews, 2);
      expect(identities, 2);
      expect(service.importedReleaseIds, {1});
    },
  );

  testWidgets('reviews duplicates before starting Discogs collection import', (
    tester,
  ) async {
    final service = _FakeImportService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsAccountProvider.overrideWithValue(
            const AsyncData<DiscogsAccount?>(
              DiscogsAccount(id: 7, username: 'hunter'),
            ),
          ),
          discogsCollectionImportServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DiscogsCollectionImportScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Review before importing'), findsOneWidget);
    expect(find.text('Vinyl found 3'), findsOneWidget);
    expect(find.text('New 1'), findsOneWidget);
    expect(find.text('Already here 1'), findsOneWidget);
    expect(find.text('Review 1'), findsOneWidget);
    expect(find.text('Import 1 record'), findsOneWidget);

    final reviewTile = find.byKey(const Key('discogs-import-release-2-2'));
    await tester.ensureVisible(reviewTile);
    await tester.tap(reviewTile);
    await tester.pump();

    expect(find.text('Import 2 records'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discogs-import-selected-button')));
    await tester.pumpAndSettle();

    expect(service.importedReleaseIds, {1, 2});
    expect(find.text('Import complete'), findsOneWidget);
    expect(find.text('2 imported • 0 skipped • 0 failed'), findsOneWidget);
  });
}

class _FakeImportService implements DiscogsCollectionImportService {
  Set<int> importedReleaseIds = {};

  @override
  Future<DiscogsCollectionImportResult> importCandidates(
    Iterable<DiscogsCollectionCandidate> candidates, {
    void Function(DiscogsImportProgress progress)? onProgress,
  }) async {
    final selected = candidates.toList(growable: false);
    importedReleaseIds = selected
        .map((candidate) => candidate.item.releaseId)
        .toSet();
    onProgress?.call(
      DiscogsImportProgress(completed: 0, total: selected.length),
    );
    onProgress?.call(
      DiscogsImportProgress(completed: selected.length, total: selected.length),
    );
    return DiscogsCollectionImportResult(
      requested: selected.length,
      imported: selected.length,
      skipped: 0,
      failures: const [],
      warnings: const [],
    );
  }

  @override
  Future<DiscogsCollectionPreview> prepare(String username) async {
    return DiscogsCollectionPreview(
      candidates: [
        DiscogsCollectionCandidate(
          item: _item(1, 1, 'New Record'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
        DiscogsCollectionCandidate(
          item: _item(2, 2, 'Possible Duplicate'),
          status: DiscogsCollectionCandidateStatus.needsReview,
          localMatchTitle: 'Artist — Possible Duplicate',
        ),
        DiscogsCollectionCandidate(
          item: _item(3, 3, 'Already Here'),
          status: DiscogsCollectionCandidateStatus.exactDuplicate,
        ),
      ],
      totalFetched: 3,
      nonVinylIgnored: 0,
    );
  }
}

DiscogsCollectionItem _item(int releaseId, int instanceId, String title) {
  return DiscogsCollectionItem(
    releaseId: releaseId,
    instanceId: instanceId,
    title: title,
    artist: 'Artist',
    formats: const ['Vinyl', 'LP'],
  );
}

class _InterruptedImportService extends _FakeImportService {
  int previews = 0;
  @override
  Future<DiscogsCollectionPreview> prepare(String username) {
    previews++;
    return super.prepare(username);
  }

  @override
  Future<DiscogsCollectionImportResult> importCandidates(
    Iterable<DiscogsCollectionCandidate> candidates, {
    void Function(DiscogsImportProgress progress)? onProgress,
  }) async {
    importedReleaseIds.add(candidates.first.item.releaseId);
    throw StateError('private interrupted import');
  }
}
