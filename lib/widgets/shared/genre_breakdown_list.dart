import 'package:flutter/material.dart';
import 'package:vinyl_app/services/stats_service.dart';

class GenreBreakdownList extends StatelessWidget {
  const GenreBreakdownList({required this.stats, super.key});

  final List<GenreStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          _GenreBreakdownRow(stat: stats[i]),
          if (i != stats.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _GenreBreakdownRow extends StatelessWidget {
  const _GenreBreakdownRow({required this.stat});

  final GenreStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = stat.share.clamp(0.0, 1.0).toDouble();
    final genreName = stat.genre.name;

    return Semantics(
      label: '$genreName, ${stat.percentage.round()} percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  genreName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${stat.percentage.round()}%',
                key: Key('genre-breakdown-percentage-$genreName'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: Key('genre-breakdown-progress-$genreName'),
              value: value,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
