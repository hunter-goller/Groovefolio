import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/widgets/shared/genre_breakdown_list.dart';

void main() {
  Widget app(List<GenreStat> stats) => MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 320, child: GenreBreakdownList(stats: stats)),
    ),
  );

  Genre genre(String id, String name) =>
      Genre(id: id, name: name, createdAt: '2026-08-15T00:00:00.000Z');

  testWidgets('renders genre names percentages and progress', (tester) async {
    final stats = [
      GenreStat(genre: genre('jazz', 'Jazz'), playCount: 41, share: 0.41),
      GenreStat(genre: genre('rock', 'Rock'), playCount: 30, share: 0.30),
      GenreStat(genre: genre('folk', 'Folk'), playCount: 17, share: 0.17),
    ];

    await tester.pumpWidget(app(stats));

    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('41%'), findsOneWidget);

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('genre-breakdown-progress-Jazz')),
    );
    expect(progress.value, 0.41);
  });

  testWidgets('empty stats render no rows', (tester) async {
    await tester.pumpWidget(app(const []));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('long names do not overflow narrow layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(180, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final stats = [
      GenreStat(
        genre: genre(
          'long',
          'Extremely Long Progressive Psychedelic Rock Genre',
        ),
        playCount: 1,
        share: 1,
      ),
    ];

    await tester.pumpWidget(app(stats));

    expect(tester.takeException(), isNull);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('progress values are clamped defensively', (tester) async {
    final stats = [
      GenreStat(genre: genre('high', 'Too High'), playCount: 2, share: 1.25),
      GenreStat(genre: genre('low', 'Too Low'), playCount: 0, share: -0.25),
    ];

    await tester.pumpWidget(app(stats));

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('genre-breakdown-progress-Too High')),
          )
          .value,
      1.0,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('genre-breakdown-progress-Too Low')),
          )
          .value,
      0.0,
    );
  });
}
