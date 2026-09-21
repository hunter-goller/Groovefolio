import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  testWidgets('no-play Stats state opens Log Play from its CTA', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final currentYear = DateTime.now().year;
    final router = GoRouter(
      initialLocation: AppRoutes.stats,
      routes: [
        GoRoute(
          path: AppRoutes.stats,
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: AppRoutes.logPlay,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Log Play test'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsDashboardProvider.overrideWith((ref, range) async {
            return StatsDashboardData(
              summary: const CollectionSummary(
                totalAlbums: 2,
                playedAlbums: 0,
                totalPlays: 0,
                averagePlaysPerWeek: 0,
              ),
              months: [
                for (var month = 1; month <= 12; month++)
                  MonthlyPlays(year: currentYear, month: month, playCount: 0),
              ],
              years: const [],
              genres: const [],
              mostPlayed: const [],
              topArtists: const [],
              firstVinyl: null,
              firstVinylArtistName: null,
            );
          }),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No plays yet'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('stats-log-play')));
    await tester.tap(find.byKey(const Key('stats-log-play')));
    await tester.pumpAndSettle();

    expect(find.text('Log Play test'), findsOneWidget);
  });

  testWidgets('shows collection coverage and top artists', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final currentYear = DateTime.now().year;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsDashboardProvider.overrideWith((ref, range) async {
            return StatsDashboardData(
              summary: const CollectionSummary(
                totalAlbums: 3,
                playedAlbums: 2,
                totalPlays: 3,
                averagePlaysPerWeek: 1.5,
              ),
              months: [
                for (var month = 1; month <= 12; month++)
                  MonthlyPlays(
                    year: currentYear,
                    month: month,
                    playCount: month == DateTime.now().month ? 3 : 0,
                  ),
              ],
              years: [YearlyPlays(year: currentYear, playCount: 3)],
              genres: const [],
              mostPlayed: const [],
              topArtists: const [
                StatsRankedArtist(
                  artistName: 'Miles Davis',
                  playCount: 3,
                  albumCount: 2,
                ),
              ],
              firstVinyl: null,
              firstVinylArtistName: null,
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const StatsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('played in $currentYear'), findsOneWidget);
    await tester.ensureVisible(find.text('Top artists'));
    expect(find.text('Miles Davis'), findsOneWidget);
    expect(find.text('2 records played'), findsOneWidget);
    expect(find.text('3 plays'), findsAtLeastNWidgets(1));
  });
}
