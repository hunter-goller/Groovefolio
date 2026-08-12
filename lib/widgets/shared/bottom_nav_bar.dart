import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Primary app navigation shared by Collection, Stats, and Discover.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  }) : assert(currentIndex >= 0 && currentIndex <= 2);

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
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
        onDestinationSelected: onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.album_outlined),
            selectedIcon: Icon(Icons.album_rounded),
            label: 'Collection',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
        ],
      ),
    );
  }
}
