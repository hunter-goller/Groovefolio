import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Compact overview of the currently visible collection.
class SummaryBar extends StatelessWidget {
  const SummaryBar({
    required this.recordCount,
    required this.totalPlays,
    super.key,
  });

  final int recordCount;
  final int totalPlays;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                value: '$recordCount',
                label: recordCount == 1 ? 'Record' : 'Records',
              ),
            ),
            SizedBox(
              height: 36,
              child: VerticalDivider(
                width: tokens.space24,
                color: tokens.textMuted.withValues(alpha: 0.24),
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                value: '$totalPlays',
                label: totalPlays == 1 ? 'Play' : 'Plays',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.theme.textTheme.headlineSmall?.copyWith(
            color: tokens.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.space4),
        Text(
          label,
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: tokens.textMuted,
          ),
        ),
      ],
    );
  }
}
