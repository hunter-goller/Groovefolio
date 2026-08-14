import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Reusable search input with a clear action that appears only when needed.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    this.hint,
    this.onClear,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final showClear = onClear != null && value.text.isNotEmpty;

        return TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          onTap: onTap,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: tokens.surface,
            prefixIcon: Icon(Icons.search_rounded, color: tokens.textMuted),
            suffixIcon: showClear
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                    },
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusXLarge),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusXLarge),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusXLarge),
              borderSide: BorderSide(
                color: context.theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
