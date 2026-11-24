import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

StatsDashboardData _data(StatsInsights? insights) {
  final year = DateTime.now().year;
  return StatsDashboardData(
    summary: const CollectionSummary(
      totalAlbums: 24,
      playedAlbums: 13,
      totalPlays: 201,
      averagePlaysPerWeek: 4.3,
    ),
    months: [
      for (var month = 1; month <= 12; month++)
        MonthlyPlays(year: year, month: month, playCount: 10),
    ],
    years: const [],
    genres: const [],
    mostPlayed: const [],
    topArtists: const [],
    firstVinyl: null,
    firstVinylArtistName: null,
    insights: insights,
  );
}

StatsInsights _insights({
  int current = 0,
  int longest = 0,
  int period = 0,
  int previous = 0,
  int? weekday,
  int weekdayPlays = 0,
  int never = 0,
  int sideA = 0,
  int sideB = 0,
}) => StatsInsights(
  currentStreakDays: current,
  longestStreakDays: longest,
  periodPlays: period,
  previousPeriodPlays: previous,
  busiestWeekday: weekday,
  busiestWeekdayPlays: weekdayPlays,
  neverPlayedAlbums: never,
  sideAPlays: sideA,
  sideBPlays: sideB,
);

Future<void> _pump(WidgetTester tester, StatsInsights? insights) async {
  await tester.binding.setSurfaceSize(const Size(412, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        statsDashboardProvider.overrideWith(
          (ref, range) async => _data(insights),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const StatsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows one plain sentence per fact', (tester) async {
    final year = DateTime.now().year;
    await _pump(
      tester,
      _insights(
        current: 4,
        longest: 12,
        period: 123,
        previous: 100,
        weekday: DateTime.sunday,
        weekdayPlays: 40,
        never: 11,
        sideA: 30,
        sideB: 10,
      ),
    );

    expect(find.byKey(const Key('stats-insights')), findsOneWidget);
    expect(find.text('4 days in a row'), findsOneWidget);
    expect(
      find.text('Your best is 12 days. Play something today to keep it going.'),
      findsOneWidget,
    );
    expect(
      find.text('23% more listening than this time last year'),
      findsOneWidget,
    );
    expect(
      find.text(
        '123 plays so far in $year, 100 plays by today in ${year - 1}.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sunday is your record day'), findsOneWidget);
    expect(find.text('Side A gets 3× the spins'), findsOneWidget);
    expect(find.text('11 records have never been played'), findsOneWidget);
  });

  testWidgets('hides facts that are not meaningful', (tester) async {
    await _pump(
      tester,
      _insights(
        current: 1,
        longest: 1,
        period: 10,
        previous: 0,
        sideA: 3,
        sideB: 2,
      ),
    );
    expect(find.byKey(const Key('stats-insights')), findsNothing);
  });

  testWidgets('small changes read as about the same', (tester) async {
    await _pump(tester, _insights(period: 102, previous: 100));
    expect(find.text('Listening about as much as last year'), findsOneWidget);
  });

  testWidgets('a lapsed streak shows the best one', (tester) async {
    await _pump(tester, _insights(longest: 9));
    expect(find.text('Best streak: 9 days'), findsOneWidget);
  });
}
