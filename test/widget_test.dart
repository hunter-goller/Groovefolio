import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/main.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/onboarding_service.dart';

void main() {
  testWidgets('App boots and resolves to the Collection screen', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          discogsDeepLinksEnabledProvider.overrideWithValue(false),
          onboardingRequiredProvider.overrideWithValue(const AsyncData(false)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'My collection'), findsOneWidget);
    expect(find.byKey(const Key('collection-empty-state')), findsOneWidget);
    expect(find.byKey(const Key('collection-search-field')), findsNothing);
    expect(find.text('Recent'), findsNothing);
    expect(find.text('A–Z'), findsNothing);
    expect(find.text('Most played'), findsNothing);
  });
}
