import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Shows onboarding only for a fresh, incomplete collection.
/// A running walkthrough bypasses this gate so navigation into Collection
/// does not display the welcome screen again.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(walkthroughProvider).active) return child;
    return ref
        .watch(onboardingRequiredProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) => Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(context.tokens.space24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40),
                      SizedBox(height: context.tokens.space12),
                      const Text('Couldn’t start Groovefolio'),
                      SizedBox(height: context.tokens.space16),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(onboardingRequiredProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          data: (required) => required ? const OnboardingScreen() : child,
        );
  }
}
