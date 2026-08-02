// Smoke test: confirms the app boots and resolves to the Collection
// screen (the initialLocation in routerProvider). Replaces the default
// flutter create counter test, which no longer matches MyApp's structure
// now that MaterialApp.router + go_router are in place (VinylApp-005).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/main.dart';

void main() {
  testWidgets('App boots and resolves to the Collection screen', (
    WidgetTester tester,
  ) async {
    // MyApp is a ConsumerWidget, so it must be pumped under a
    // ProviderScope or ref.watch() inside build() will throw.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // AppBar title on CollectionScreen — stable regardless of
    // whatever placeholder body content is currently in place.
    expect(find.text('Collection'), findsOneWidget);
  });
}
