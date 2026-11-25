import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/widgets/genre_filter_sheet.dart';
import 'package:vinyl_app/theme/app_theme.dart';

Genre _genre(String name) =>
    Genre(id: 'g-$name', name: name, createdAt: '2026-11-01T00:00:00.000Z');

void main() {
  group('rankGenreFilterOptions', () {
    final rock = _genre('Rock');
    final jazz = _genre('Jazz');
    final funk = _genre('Funk');
    final unused = _genre('Polka');

    test('counts records, most-used first, and drops unused genres', () {
      final options = rankGenreFilterOptions(
        genres: [funk, jazz, rock, unused],
        genresByAlbum: {
          'a': [rock, jazz],
          'b': [rock],
          'c': [rock, funk],
          'd': [jazz],
        },
        albumIds: ['a', 'b', 'c', 'd'],
      );
      expect(
        [for (final o in options) '${o.name} ${o.count}'],
        ['Rock 3', 'Jazz 2', 'Funk 1'],
      );
    });

    test('matches names ignoring case and ties sort by name', () {
      final options = rankGenreFilterOptions(
        genres: [rock, jazz],
        genresByAlbum: {
          'a': [_genre('ROCK')],
          'b': [_genre('jazz')],
        },
        albumIds: ['a', 'b'],
      );
      expect([for (final o in options) o.name], ['Jazz', 'Rock']);
    });

    test('ignores records not in the collection', () {
      final options = rankGenreFilterOptions(
        genres: [rock],
        genresByAlbum: {
          'gone': [rock],
        },
        albumIds: const ['a'],
      );
      expect(options, isEmpty);
    });

    test('keeps the selected genre even when nothing uses it', () {
      final options = rankGenreFilterOptions(
        genres: [rock, unused],
        genresByAlbum: {
          'a': [rock],
        },
        albumIds: ['a'],
        selected: 'polka',
      );
      expect(
        [for (final o in options) '${o.name} ${o.count}'],
        ['Rock 1', 'Polka 0'],
      );
    });
  });

  group('GenreFilterSheet', () {
    Future<List<String?>> pump(
      WidgetTester tester,
      List<GenreFilterOption> options, {
      String? selected,
    }) async {
      final results = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => results.add(
                  await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => GenreFilterSheet(
                      options: options,
                      totalRecords: 12,
                      selected: selected,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    final many = [
      for (var i = 0; i < 12; i++) GenreFilterOption('Genre $i', 12 - i),
    ];
    Finder row(String name) => find.byKey(ValueKey('collection-genre-$name'));
    Finder quick(String name) =>
        find.byKey(ValueKey('collection-genre-top-$name'));

    testWidgets('a short list is just rows with counts', (tester) async {
      final results = await pump(tester, const [
        GenreFilterOption('Rock', 7),
        GenreFilterOption('Jazz', 3),
      ]);
      expect(
        find.byKey(const Key('collection-genre-filter-search')),
        findsNothing,
      );
      expect(find.text('MOST USED'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('collection-genre-all')),
          matching: find.text('12'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('Rock'), matching: find.text('7')),
        findsOneWidget,
      );
      // A–Z: Jazz above Rock, even though Rock is used more.
      expect(
        tester.getTopLeft(row('Jazz')).dy,
        lessThan(tester.getTopLeft(row('Rock')).dy),
      );
      await tester.tap(row('Jazz'));
      await tester.pumpAndSettle();
      expect(results, ['Jazz']);
    });

    testWidgets('a long list adds search and the most-used quick picks', (
      tester,
    ) async {
      final results = await pump(tester, many);
      expect(
        find.byKey(const Key('collection-genre-filter-search')),
        findsOneWidget,
      );
      expect(find.text('Search 12 genres'), findsOneWidget);
      expect(find.text('MOST USED'), findsOneWidget);
      for (var i = 0; i < GenreFilterSheet.quickPicks; i++) {
        expect(quick('Genre $i'), findsOneWidget);
      }
      expect(quick('Genre ${GenreFilterSheet.quickPicks}'), findsNothing);
      await tester.tap(quick('Genre 2'));
      await tester.pumpAndSettle();
      expect(results, ['Genre 2']);
    });

    testWidgets('the selected genre is ticked and Clear removes it', (
      tester,
    ) async {
      final results = await pump(tester, many, selected: 'genre 3');
      expect(
        find.descendant(
          of: row('Genre 3'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.widget<ChoiceChip>(quick('Genre 3')).selected, isTrue);
      await tester.tap(find.byKey(const Key('collection-genre-clear')));
      await tester.pumpAndSettle();
      expect(results, ['']);
    });

    testWidgets('All records clears the filter too', (tester) async {
      final results = await pump(tester, const [
        GenreFilterOption('Rock', 7),
      ], selected: 'Rock');
      await tester.tap(find.byKey(const Key('collection-genre-all')));
      await tester.pumpAndSettle();
      expect(results, ['']);
    });

    testWidgets('no Clear button when nothing is selected', (tester) async {
      await pump(tester, many);
      expect(find.byKey(const Key('collection-genre-clear')), findsNothing);
    });

    testWidgets('search narrows the list to matching rows', (tester) async {
      await pump(tester, many);
      await tester.enterText(
        find.byKey(const Key('collection-genre-filter-search')),
        'genre 1',
      );
      await tester.pumpAndSettle();
      expect(row('Genre 1'), findsOneWidget);
      expect(row('Genre 10'), findsOneWidget);
      expect(row('Genre 11'), findsOneWidget);
      expect(row('Genre 2'), findsNothing);
      expect(find.text('MOST USED'), findsNothing);
      expect(find.byKey(const Key('collection-genre-all')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says when no genre matches the search', (tester) async {
      await pump(tester, many);
      await tester.enterText(
        find.byKey(const Key('collection-genre-filter-search')),
        'zydeco',
      );
      await tester.pumpAndSettle();
      expect(find.text('No genres match “zydeco”.'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('MOST USED'), findsOneWidget);
      expect(row('Genre 0'), findsOneWidget);
    });

    testWidgets('long names fit a narrow phone with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, [
        const GenreFilterOption(
          'Progressive Psychedelic Post-Rock Instrumental',
          1234,
        ),
        ...many,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explains an empty list', (tester) async {
      await pump(tester, const []);
      expect(
        find.textContaining('None of your records have a genre yet'),
        findsOneWidget,
      );
    });
  });
}
