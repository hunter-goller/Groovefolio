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
}
