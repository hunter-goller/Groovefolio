import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';

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
              child: AppErrorState(
                key: const Key('onboarding-gate-error-state'),
                title: 'Couldn’t start Groovefolio',
                message: 'Couldn’t read your setup progress. Try again.',
                error: error,
                stackTrace: stackTrace,
                operation: 'read onboarding status',
                onRetry: () => ref.invalidate(onboardingRequiredProvider),
                retryButtonKey: const Key('onboarding-gate-error-retry'),
              ),
            ),
          ),
          data: (required) => required ? const OnboardingScreen() : child,
        );
  }
}
