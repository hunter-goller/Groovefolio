import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';

/// A value/label pair rendered by [FilterChipRow].
class FilterChipOption<T> {
  const FilterChipOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Horizontally scrollable single-select chip row.
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<FilterChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            _FilterChoiceChip<T>(
              option: options[index],
              isSelected: options[index].value == selected,
              onSelected: () => onChanged(options[index].value),
            ),
            if (index != options.length - 1) SizedBox(width: tokens.space8),
          ],
        ],
      ),
    );
  }
}

class _FilterChoiceChip<T> extends StatelessWidget {
  const _FilterChoiceChip({
    required this.option,
    required this.isSelected,
    required this.onSelected,
  });

  final FilterChipOption<T> option;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      avatar: option.icon == null
          ? null
          : Icon(
              option.icon,
              size: 16,
              color: isSelected ? Colors.black : tokens.textMuted,
            ),
      label: Text(option.label),
      selectedColor: AppThemeTokens.accent,
      backgroundColor: tokens.surface,
      side: BorderSide(
        color: isSelected
            ? AppThemeTokens.accent
            : tokens.textMuted.withValues(alpha: 0.24),
      ),
      labelStyle: context.theme.textTheme.labelLarge?.copyWith(
        color: isSelected ? Colors.black : tokens.textMuted,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
