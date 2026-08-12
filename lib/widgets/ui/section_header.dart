import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Section label with optional trailing text or action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
    super.key,
  }) : assert(
         onTrailingTap == null || trailing != null,
         'A trailing action requires trailing text.',
       );

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final trailingText = trailing;

    return Padding(
      padding: EdgeInsets.only(top: tokens.space24, bottom: tokens.space12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.theme.textTheme.titleMedium?.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailingText != null)
            onTrailingTap == null
                ? Text(
                    trailingText,
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: tokens.textMuted.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : TextButton(
                    onPressed: onTrailingTap,
                    child: Text(trailingText),
                  ),
        ],
      ),
    );
  }
}
