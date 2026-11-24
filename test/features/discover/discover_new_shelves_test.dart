import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/discover/screens/discover_screen.dart';
import 'package:vinyl_app/services/recommendation_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

AlbumRecommendation _pick(String id, String title, RecommendationKind kind) =>
    AlbumRecommendation(
      album: Album(
        id: id,
        title: title,
        artistId: 'artist',
        createdAt: '2026-01-01T00:00:00.000Z',
      ),
      artistName: 'Artist',
      genres: const [],
      reason: 'Reason for $title',
      kind: kind,
      playCount: 1,
      score: 1,
    );

Future<void> _pump(WidgetTester tester, DiscoverRecommendations data) async {
  await tester.binding.setSurfaceSize(const Size(412, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        discoverRecommendationsProvider.overrideWith((ref) async => data),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const DiscoverScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the pairing and deep-cut shelves with their titles', (
    tester,
  ) async {
    await _pump(
      tester,
      DiscoverRecommendations(
        collectionSize: 3,
        tasteProfile: null,
        rediscover: const [],
        genrePicks: const [],
        eraPicks: const [],
        pairings: [_pick('bt', 'Blue Train', RecommendationKind.pairing)],
        pairingSeedTitle: 'Kind of Blue',
        deepCuts: [_pick('tusk', 'Tusk', RecommendationKind.deepCut)],
      ),
    );

    expect(find.byKey(const Key('discover-daily-note')), findsOneWidget);
    expect(find.text('Because you played Kind of Blue'), findsOneWidget);
    expect(find.text('Reason for Blue Train'), findsOneWidget);
    expect(find.text('Deep cuts from artists you love'), findsOneWidget);
    expect(find.text('Reason for Tusk'), findsOneWidget);
  });

  testWidgets('pairings for several records use a general title', (
    tester,
  ) async {
    await _pump(
      tester,
      DiscoverRecommendations(
        collectionSize: 2,
        tasteProfile: null,
        rediscover: const [],
        genrePicks: const [],
        eraPicks: const [],
        pairings: [_pick('bt', 'Blue Train', RecommendationKind.pairing)],
      ),
    );
    expect(find.text('Goes with what you’re playing'), findsOneWidget);
    expect(find.byKey(const Key('discover-deep-cuts')), findsNothing);
  });
}
