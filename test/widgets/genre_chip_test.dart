import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/shared/genre_chip.dart';

void main() {
  Widget buildSubject(
    GenreChip chip, {
    double textScaleFactor = 1,
    double width = 320,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
        child: Scaffold(
          body: SizedBox(width: width, child: chip),
        ),
      ),
    );
  }

  testWidgets('non-removable chip has no close icon or InkWell', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const GenreChip(genre: 'Jazz')));

    expect(find.text('Jazz'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('removable chip shows close icon and invokes onRemove', (
    tester,
  ) async {
    var removeCount = 0;

    await tester.pumpWidget(
      buildSubject(
        GenreChip(
          genre: 'Rock',
          removable: true,
          onRemove: () => removeCount++,
        ),
      ),
    );

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.text('Rock'));
    await tester.pump();
    expect(removeCount, 1);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(removeCount, 2);
  });

  testWidgets('genre text stays compact at fixed scale', (tester) async {
    await tester.pumpWidget(
      buildSubject(const GenreChip(genre: 'Alternative'), textScaleFactor: 2.5),
    );

    final text = tester.widget<Text>(find.text('Alternative'));
    expect(text.style?.fontSize, 10);
    expect(text.style?.fontWeight, FontWeight.w600);
    expect(text.textScaler, TextScaler.noScaling);
  });

  test('genre colors are deterministic after normalization', () {
    expect(genreColorIndex('Jazz'), genreColorIndex(' jazz '));
    expect(genreColorIndex('HARD BOP'), genreColorIndex('hard bop'));
    expect(genreColorIndex('Jazz'), isNot(genreColorIndex('Hard Bop')));
  });

  testWidgets('identical genres produce identical chip geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Row(
            children: [
              GenreChip(key: Key('first'), genre: 'Soul'),
              GenreChip(key: Key('second'), genre: 'Soul'),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('first'))),
      tester.getSize(find.byKey(const Key('second'))),
    );
  });

  testWidgets('chips wrap in narrow layouts without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(
            width: 120,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                GenreChip(genre: 'Alternative'),
                GenreChip(genre: 'Electronic'),
                GenreChip(genre: 'Jazz'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GenreChip), findsNWidgets(3));
  });
}
