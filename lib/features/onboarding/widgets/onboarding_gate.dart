import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                message: 'Your local data is safe. Try opening the app again.',
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
