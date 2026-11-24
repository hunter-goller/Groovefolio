import 'package:flutter/material.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_target.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';

/// Reusable empty/error state with optional primary and secondary actions.
///
/// [footer] sits under the actions, for status text such as a save result.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCtaTap,
    this.ctaKey,
    this.secondaryCtaLabel,
    this.onSecondaryCtaTap,
    this.secondaryCtaKey,
    this.secondaryCtaIcon,
    this.secondaryCtaLoading = false,
    this.footer,
    this.ctaSpotlight,
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
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCtaTap;
  final Key? secondaryCtaKey;
  final IconData? secondaryCtaIcon;
  final bool secondaryCtaLoading;
  final Widget? footer;

  /// Lets the tutorial spotlight the button.
  final SpotlightId? ctaSpotlight;

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
            if (ctaSpotlight == null)
              PrimaryButton(key: ctaKey, label: ctaLabel!, onPressed: onCtaTap)
            else
              SpotlightTarget(
                id: ctaSpotlight!,
                child: PrimaryButton(
                  key: ctaKey,
                  label: ctaLabel!,
                  onPressed: onCtaTap,
                ),
              ),
          ],
          if (secondaryCtaLabel != null) ...[
            SizedBox(height: tokens.space12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                key: secondaryCtaKey,
                onPressed: secondaryCtaLoading ? null : onSecondaryCtaTap,
                icon: secondaryCtaLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(secondaryCtaIcon ?? Icons.save_alt_outlined),
                label: Text(
                  secondaryCtaLoading ? 'Saving…' : secondaryCtaLabel!,
                ),
              ),
            ),
          ],
          if (footer != null) ...[SizedBox(height: tokens.space16), footer!],
        ],
      ),
    );
  }
}
