import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';
import 'package:vinyl_app/widgets/shared/bottom_nav_bar.dart';
import 'package:vinyl_app/widgets/shared/genre_breakdown_list.dart';

enum StatsRange { currentYear, allTime }

class StatsRankedAlbum {
  const StatsRankedAlbum({
    required this.album,
    required this.artistName,
    required this.playCount,
  });

  final Album album;
  final String artistName;
  final int playCount;
}

class StatsDashboardData {
  const StatsDashboardData({
    required this.summary,
    required this.months,
    required this.years,
    required this.genres,
    required this.mostPlayed,
    required this.firstVinyl,
    required this.firstVinylArtistName,
  });

  final CollectionSummary summary;
  final List<MonthlyPlays> months;
  final List<YearlyPlays> years;
  final List<GenreStat> genres;
  final List<StatsRankedAlbum> mostPlayed;
  final Album? firstVinyl;
  final String? firstVinylArtistName;
}

final statsDashboardProvider = FutureProvider.autoDispose
    .family<StatsDashboardData, StatsRange>((ref, range) async {
      final service = ref.watch(statsServiceProvider);
      final artistRepository = ref.watch(artistRepositoryProvider);
      final currentYear = DateTime.now().year;
      final filteredYear = range == StatsRange.currentYear ? currentYear : null;

      final summaryFuture = service.getCollectionSummary(year: filteredYear);
      final monthsFuture = service.getPlaysByMonth(currentYear);
      final yearsFuture = service.getPlaysByYear();
      final genresFuture = service.getGenreBreakdown(year: filteredYear);
      final rankedFuture = service.getMostPlayedAlbums(5, year: filteredYear);
      final firstVinylFuture = service.getFirstVinyl();
      final artistsFuture = artistRepository.findAll();

      final summary = await summaryFuture;
      final months = await monthsFuture;
      final years = await yearsFuture;
      final genres = await genresFuture;
      final ranked = await rankedFuture;
      final firstVinyl = await firstVinylFuture;
      final artists = await artistsFuture;
      final artistsById = {
        for (final artist in artists) artist.id: artist.name,
      };

      return StatsDashboardData(
        summary: summary,
        months: months,
        years: years,
        genres: genres,
        mostPlayed: [
          for (final item in ranked)
            StatsRankedAlbum(
              album: item.album,
              artistName: artistsById[item.album.artistId] ?? 'Unknown artist',
              playCount: item.playCount,
            ),
        ],
        firstVinyl: firstVinyl,
        firstVinylArtistName: firstVinyl == null
            ? null
            : artistsById[firstVinyl.artistId] ?? 'Unknown artist',
      );
    });

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsRange _range = StatsRange.currentYear;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final dataAsync = ref.watch(statsDashboardProvider(_range));
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your stats'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<StatsRange>(
              segments: [
                ButtonSegment(
                  value: StatsRange.currentYear,
                  label: Text('$currentYear'),
                ),
                const ButtonSegment(
                  value: StatsRange.allTime,
                  label: Text('All time'),
                ),
              ],
              selected: {_range},
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppThemeTokens.accent.withValues(alpha: 0.18);
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppThemeTokens.accent;
                  }
                  return tokens.text;
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return BorderSide(
                    color: selected
                        ? AppThemeTokens.accent.withValues(alpha: 0.78)
                        : tokens.textMuted.withValues(alpha: 0.55),
                  );
                }),
              ),
              onSelectionChanged: (selection) {
                setState(() => _range = selection.single);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _StatsErrorState(
            onRetry: () => ref.invalidate(statsDashboardProvider(_range)),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(statsDashboardProvider);
              await ref.read(statsDashboardProvider(_range).future);
            },
            child: _StatsBody(
              data: data,
              range: _range,
              currentYear: currentYear,
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          const routes = [
            AppRoutes.collection,
            AppRoutes.stats,
            AppRoutes.discover,
          ];
          context.go(routes[index]);
        },
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.data,
    required this.range,
    required this.currentYear,
  });

  final StatsDashboardData data;
  final StatsRange range;
  final int currentYear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentMonthPlays = data.months[DateTime.now().month - 1].playCount;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space8,
        tokens.space16,
        tokens.space32,
      ),
      children: [
        _SummaryGrid(
          summary: data.summary,
          currentMonthPlays: currentMonthPlays,
          range: range,
          currentYear: currentYear,
        ),
        if (data.firstVinyl != null) ...[
          SizedBox(height: tokens.space16),
          _FirstVinylCard(
            album: data.firstVinyl!,
            artistName: data.firstVinylArtistName ?? 'Unknown artist',
          ),
        ],
        SizedBox(height: tokens.space24),
        if (data.summary.totalPlays == 0)
          const _NoPlaysCard()
        else ...[
          if (range == StatsRange.currentYear)
            _StatsSectionCard(
              title: 'Plays in $currentYear',
              trailing: Text(
                '$currentYear',
                style: context.theme.textTheme.labelMedium?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
              child: _MonthlyBarChart(months: data.months),
            )
          else
            _StatsSectionCard(
              title: 'Plays by year',
              trailing: Text(
                'All time',
                style: context.theme.textTheme.labelMedium?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
              child: _YearlyBarChart(years: data.years),
            ),
          SizedBox(height: tokens.space16),
          if (data.genres.isNotEmpty)
            _StatsSectionCard(
              title: 'Listening by genre',
              child: _ExpandableGenreBreakdown(
                key: ValueKey(range),
                stats: data.genres,
              ),
            ),
          if (data.genres.isNotEmpty) SizedBox(height: tokens.space16),
          if (data.mostPlayed.isNotEmpty)
            _StatsSectionCard(
              title: 'Most played',
              child: Column(
                children: [
                  for (var i = 0; i < data.mostPlayed.length; i++) ...[
                    _RankedAlbumRow(rank: i + 1, item: data.mostPlayed[i]),
                    if (i != data.mostPlayed.length - 1)
                      Divider(
                        height: tokens.space24,
                        color: tokens.textMuted.withValues(alpha: 0.16),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.currentMonthPlays,
    required this.range,
    required this.currentYear,
  });

  final CollectionSummary summary;
  final int currentMonthPlays;
  final StatsRange range;
  final int currentYear;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        _StatTile(
          label: 'COLLECTION',
          value: '${summary.totalAlbums}',
          detail: summary.totalAlbums == 1 ? 'record' : 'records',
        ),
        _StatTile(
          label: 'TOTAL PLAYS',
          value: '${summary.totalPlays}',
          detail: range == StatsRange.currentYear
              ? 'in $currentYear'
              : 'all time',
        ),
        _StatTile(
          label: _monthName(DateTime.now().month).toUpperCase(),
          value: '$currentMonthPlays',
          detail: 'plays',
        ),
        _StatTile(
          label: 'AVG / WEEK',
          value: summary.averagePlaysPerWeek.toStringAsFixed(1),
          detail: 'plays',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.13)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    detail,
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FirstVinylCard extends StatelessWidget {
  const _FirstVinylCard({required this.album, required this.artistName});

  final Album album;
  final String artistName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final added = DateTime.tryParse(album.createdAt)?.toLocal();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppThemeTokens.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
        border: Border.all(
          color: AppThemeTokens.accent.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Row(
          children: [
            const Icon(Icons.album_rounded, color: AppThemeTokens.accent),
            SizedBox(width: tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIRST VINYL',
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: AppThemeTokens.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    added == null
                        ? artistName
                        : '$artistName · Added ${_monthName(added.month)} '
                              '${added.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableGenreBreakdown extends StatefulWidget {
  const _ExpandableGenreBreakdown({required this.stats, super.key});

  final List<GenreStat> stats;

  @override
  State<_ExpandableGenreBreakdown> createState() =>
      _ExpandableGenreBreakdownState();
}

class _ExpandableGenreBreakdownState extends State<_ExpandableGenreBreakdown> {
  static const _collapsedCount = 6;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final canExpand = widget.stats.length > _collapsedCount;
    final visibleStats = _expanded || !canExpand
        ? widget.stats
        : widget.stats.take(_collapsedCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GenreBreakdownList(stats: visibleStats),
        if (canExpand) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                _expanded ? 'Show less' : 'Show all (${widget.stats.length})',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatsSectionCard extends StatelessWidget {
  const _StatsSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.13)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: tokens.space16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({required this.months});

  final List<MonthlyPlays> months;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final maxPlays = months.fold<int>(
      0,
      (max, month) => month.playCount > max ? month.playCount : max,
    );

    return SizedBox(
      height: 145,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final month in months)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final target = maxPlays == 0
                              ? 0.0
                              : month.playCount / maxPlays;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: target),
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Container(
                                key: Key('stats-month-bar-${month.month}'),
                                height: constraints.maxHeight * value,
                                constraints: const BoxConstraints(minHeight: 2),
                                decoration: BoxDecoration(
                                  color: AppThemeTokens.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _monthInitial(month.month),
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: tokens.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YearlyBarChart extends StatelessWidget {
  const _YearlyBarChart({required this.years});

  final List<YearlyPlays> years;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (years.isEmpty) {
      return SizedBox(
        height: 110,
        child: Center(
          child: Text(
            'No listening history yet',
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textMuted,
            ),
          ),
        ),
      );
    }

    final maxPlays = years.fold<int>(
      0,
      (max, year) => year.playCount > max ? year.playCount : max,
    );
    final chartWidth = years.length <= 5 ? null : years.length * 72.0;

    final chart = SizedBox(
      width: chartWidth,
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final year in years)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${year.playCount}',
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final target = maxPlays == 0
                              ? 0.0
                              : year.playCount / maxPlays;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(
                                'stats-year-animation-${year.year}',
                              ),
                              tween: Tween(begin: 0, end: target),
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Container(
                                key: Key('stats-year-bar-${year.year}'),
                                height: constraints.maxHeight * value,
                                constraints: const BoxConstraints(minHeight: 2),
                                decoration: BoxDecoration(
                                  color: AppThemeTokens.accent,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${year.year}',
                      key: Key('stats-year-label-${year.year}'),
                      maxLines: 1,
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (chartWidth == null) return chart;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: chart,
    );
  }
}

class _RankedAlbumRow extends StatelessWidget {
  const _RankedAlbumRow({required this.rank, required this.item});

  final int rank;
  final StatsRankedAlbum item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$rank',
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: AppThemeTokens.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tokens.surfaceElevated,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
          ),
          child: const Icon(
            Icons.album_rounded,
            color: AppThemeTokens.accent,
            size: 24,
          ),
        ),
        SizedBox(width: tokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                item.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.space8),
        Text(
          '${item.playCount} ${item.playCount == 1 ? 'play' : 'plays'}',
          style: context.theme.textTheme.labelMedium?.copyWith(
            color: tokens.textMuted,
          ),
        ),
      ],
    );
  }
}

class _NoPlaysCard extends StatelessWidget {
  const _NoPlaysCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space32),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 42, color: tokens.textMuted),
          SizedBox(height: tokens.space12),
          Text(
            'No plays yet',
            style: context.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space4),
          Text(
            'Log your first play to start building listening stats.',
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsErrorState extends StatelessWidget {
  const _StatsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            SizedBox(height: tokens.space12),
            const Text('Could not load stats'),
            SizedBox(height: tokens.space12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _monthInitial(int month) => const [
  'J',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
][month - 1];

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
