import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/routing/router.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  test('routerProvider provides a configured GoRouter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    expect(router, isA<GoRouter>());
  });

  test('routerProvider can be overridden for testing', () {
    // This is the pattern for testing any widget/service that depends on
    // routerProvider without needing a real GoRouter instance.
    final testRouter = GoRouter(routes: const []);
    final container = ProviderContainer(
      overrides: [routerProvider.overrideWithValue(testRouter)],
    );
    addTearDown(container.dispose);

    expect(container.read(routerProvider), same(testRouter));
  });

  testWidgets('an unknown path shows a friendly page that returns home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/nowhere',
      errorBuilder: (context, state) => const RouteNotFoundScreen(),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('Home')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.byKey(const Key('route-not-found-home')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('the app router shows the not-found page for unknown links', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider)..go('/album/1/nope');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RouteNotFoundScreen), findsOneWidget);
  });
}
