import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';

/// Reusable empty/error state with an optional primary action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCtaTap,
    this.ctaKey,
    super.key,
  }) : assert(
         (ctaLabel == null) == (onCtaTap == null),
         'ctaLabel and onCtaTap must both be provided or both be null.',
       );

  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;
  final Key? ctaKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space16,
        vertical: tokens.space32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Icon(icon, size: 32, color: tokens.textMuted),
            ),
          ),
          SizedBox(height: tokens.space16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.titleLarge?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textMuted,
              height: 1.4,
            ),
          ),
          if (ctaLabel != null) ...[
            SizedBox(height: tokens.space24),
            PrimaryButton(key: ctaKey, label: ctaLabel!, onPressed: onCtaTap),
          ],
        ],
      ),
    );
  }
}
