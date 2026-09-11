import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/types/side_played.dart';

/// Three-way selector for Full album, Side A, and Side B.
class SideSelector extends StatelessWidget {
  const SideSelector({required this.value, required this.onChanged, super.key});

  final SidePlayed value;
  final ValueChanged<SidePlayed> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.all(tokens.space4 / 2),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          _Segment(
            label: 'Full album',
            selected: value == SidePlayed.full,
            onTap: () => onChanged(SidePlayed.full),
          ),
          _Segment(
            label: 'Side A',
            selected: value == SidePlayed.sideA,
            onTap: () => onChanged(SidePlayed.sideA),
          ),
          _Segment(
            label: 'Side B',
            selected: value == SidePlayed.sideB,
            onTap: () => onChanged(SidePlayed.sideB),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        excludeSemantics: true,
        label: label,
        hint: selected ? 'Selected' : 'Double tap to select',
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radiusSmall - 2),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? context.theme.colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radiusSmall - 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? context.theme.colorScheme.onPrimary
                      : tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
