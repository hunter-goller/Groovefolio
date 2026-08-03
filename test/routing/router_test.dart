import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/routing/router.dart';

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
}
