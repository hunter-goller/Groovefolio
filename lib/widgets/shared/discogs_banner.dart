import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';

/// Presentational entry point for Discogs release search/autofill.
///
/// Networking stays outside this widget; callers provide the current search
/// hint and launch the VinylApp-090 search flow through [onTap].
class DiscogsBanner extends StatelessWidget {
  const DiscogsBanner({
    required this.prefillQuery,
    required this.onTap,
    super.key,
  });

  final String prefillQuery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final query = prefillQuery.trim();

    return Material(
      color: tokens.surfaceElevated,
      borderRadius: BorderRadius.circular(tokens.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        child: Padding(
          padding: EdgeInsets.all(tokens.space12),
          child: Row(
            children: [
              const Icon(
                Icons.travel_explore_rounded,
                color: AppThemeTokens.accent,
              ),
              SizedBox(width: tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Discogs to autofill',
                      style: context.theme.textTheme.titleSmall?.copyWith(
                        color: tokens.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (query.isNotEmpty) ...[
                      SizedBox(height: tokens.space4),
                      Text(
                        query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
