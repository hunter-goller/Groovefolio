import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/shared/genre_chip.dart';
import 'package:vinyl_app/widgets/shared/genre_chip_input.dart';

void main() {
  Widget buildSubject({
    required List<String> genres,
    required ValueChanged<List<String>> onChanged,
    List<String> suggestions = const <String>[],
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GenreChipInput(
            genres: genres,
            suggestions: suggestions,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('renders selected genres as removable GenreChips', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(genres: const ['Rock', 'Soul'], onChanged: (_) {}),
    );

    expect(find.byType(GenreChip), findsNWidgets(2));
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('Soul'), findsOneWidget);
    expect(find.byKey(const Key('genre-add-chip')), findsOneWidget);
  });

  testWidgets('removing a genre emits the remaining values', (tester) async {
    List<String>? changed;

    await tester.pumpWidget(
      buildSubject(
        genres: const ['Rock', 'Soul'],
        onChanged: (genres) => changed = genres,
      ),
    );

    await tester.tap(find.text('Rock'));
    await tester.pump();

    expect(changed, ['Soul']);
  });

  testWidgets('add chip opens picker and adds a trimmed custom genre', (
    tester,
  ) async {
    List<String>? changed;

    await tester.pumpWidget(
      buildSubject(
        genres: const ['Rock'],
        onChanged: (genres) => changed = genres,
      ),
    );

    await tester.tap(find.byKey(const Key('genre-add-chip')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const Key('genre-picker-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('genre-picker-field')),
      '  Neo Soul  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('genre-create-chip')));
    await tester.pumpAndSettle();

    expect(changed, ['Rock', 'Neo Soul']);
  });

  testWidgets('picker filters suggestions and emits selected suggestion', (
    tester,
  ) async {
    List<String>? changed;

    await tester.pumpWidget(
      buildSubject(
        genres: const ['Rock'],
        suggestions: const ['Jazz', 'Electronic', 'Soul'],
        onChanged: (genres) => changed = genres,
      ),
    );

    await tester.tap(find.byKey(const Key('genre-add-chip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('genre-picker-field')), 'jaz');
    await tester.pump();

    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Electronic'), findsNothing);

    await tester.tap(find.text('Jazz'));
    await tester.pumpAndSettle();

    expect(changed, ['Rock', 'Jazz']);
  });

  testWidgets('already-selected suggestions are excluded case-insensitively', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        genres: const ['Rock'],
        suggestions: const ['rock', 'Jazz'],
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byKey(const Key('genre-add-chip')));
    await tester.pumpAndSettle();

    expect(find.text('rock'), findsNothing);
    expect(find.text('Jazz'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('genre-picker-field')), 'ROCK');
    await tester.pump();

    expect(find.byKey(const Key('genre-create-chip')), findsNothing);
  });

  testWidgets('cancel closes picker without emitting a change', (tester) async {
    var changeCount = 0;

    await tester.pumpWidget(
      buildSubject(genres: const ['Rock'], onChanged: (_) => changeCount++),
    );

    await tester.tap(find.byKey(const Key('genre-add-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(changeCount, 0);
  });

  testWidgets('input wraps selected chips and add action in narrow layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 130,
            child: GenreChipInput(
              genres: const ['Alternative', 'Electronic', 'Jazz'],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GenreChip), findsNWidgets(3));
  });
}
