import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/widgets/guide_target.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Primary app navigation shared by Collection, Stats, and Discover.
class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  }) : assert(currentIndex >= 0 && currentIndex <= 2);

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: context.theme.colorScheme.primary.withValues(
          alpha: 0.18,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return context.theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? context.theme.colorScheme.primary
                : tokens.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? context.theme.colorScheme.primary
                : tokens.textMuted,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          final guide = ref.read(walkthroughProvider);
          if (guide.active &&
              guide.step == 6 &&
              currentIndex == 1 &&
              index == 2) {
            ref.read(walkthroughProvider.notifier).move(7);
          } else {
            onTap(index);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.album_outlined),
            selectedIcon: Icon(Icons.album_rounded),
            label: 'Collection',
          ),
          NavigationDestination(
            icon: GuideTarget(
              steps: currentIndex == 0 ? const [6] : const [],
              child: const Icon(Icons.bar_chart_outlined),
            ),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: GuideTarget(
              steps: currentIndex == 1 ? const [6] : const [],
              child: const Icon(Icons.explore_outlined),
            ),
            selectedIcon: const Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
        ],
      ),
    );
  }
}
