import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// Shows onboarding only for a fresh, incomplete collection. If its status
/// can't be read, the collection opens instead: onboarding is never a reason
/// to lock someone out of their records.
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
          // If setup progress can't be read (for example after the phone's
          // keystore changes), the collection itself is fine. Open it rather
          // than blocking the user behind an error with only Retry.
          error: (error, stackTrace) {
            logAppError('read onboarding status', error, stackTrace);
            return child;
          },
          data: (required) => required ? const OnboardingScreen() : child,
        );
  }
}
