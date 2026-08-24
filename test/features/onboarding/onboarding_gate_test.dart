import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/onboarding/widgets/onboarding_gate.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  testWidgets('required onboarding replaces the collection on first run', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRequiredProvider.overrideWithValue(const AsyncData(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingGate(child: Text('Collection test')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your record shelf, remembered'), findsOneWidget);
    expect(find.text('Collection test'), findsNothing);
  });

  testWidgets('completed onboarding shows the collection', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRequiredProvider.overrideWithValue(const AsyncData(false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingGate(child: Text('Collection test')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collection test'), findsOneWidget);
    expect(find.text('Your record shelf, remembered'), findsNothing);
  });
}
