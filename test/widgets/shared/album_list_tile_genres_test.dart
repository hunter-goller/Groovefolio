import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/shared/album_list_tile.dart';

void main() {
  testWidgets('renders display-only genres and wraps at constrained width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 250,
              child: AlbumListTile(
                title: 'Blue Train',
                artist: 'John Coltrane',
                releaseYear: 1957,
                playCount: 6,
                genres: ['Jazz', 'Hard Bop', 'Post-Bop With A Longer Name'],
                onTap: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Hard Bop'), findsOneWidget);
    expect(find.text('Post-Bop With A Longer Name'), findsOneWidget);
    expect(find.byKey(const Key('album-list-genres')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits genre container when an album has no genres', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AlbumListTile(
            title: 'Blue Train',
            artist: 'John Coltrane',
            playCount: 0,
            onTap: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('album-list-genres')), findsNothing);
  });

  testWidgets('exposes one useful TalkBack action for a record', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlbumListTile(
            title: 'Blue Train',
            artist: 'John Coltrane',
            playCount: 6,
            lastPlayedAt: DateTime.now(),
            onTap: _noop,
            onLongPress: _noop,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(AlbumListTile));
    expect(semantics.label, contains('Blue Train by John Coltrane'));
    expect(semantics.label, contains('6 plays'));
    expect(semantics.hint, contains('Long press for record actions'));
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    expect(semantics.hasAction(SemanticsAction.longPress), isTrue);
  });
}

void _noop() {}
