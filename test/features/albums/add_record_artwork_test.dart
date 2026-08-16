import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/widgets/shared/artwork_picker.dart';

void main() {
  testWidgets('Add Record uses the reusable ArtworkPicker', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.addAlbum,
      routes: [
        GoRoute(
          path: AppRoutes.addAlbum,
          builder: (context, state) => const AddRecordScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [genreRepositoryProvider.overrideWithValue(_Genres())],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ArtworkPicker), findsOneWidget);
    expect(find.byKey(const Key('add-record-artwork')), findsOneWidget);
    expect(find.text('Artwork picker is coming soon.'), findsNothing);
  });
}

class _Genres implements IGenreRepository {
  @override
  Future<List<Genre>> findAll() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
