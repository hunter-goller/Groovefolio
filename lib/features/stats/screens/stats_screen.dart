import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_target.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/badge_shelf_card.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';
import 'package:vinyl_app/widgets/shared/bottom_nav_bar.dart';
import 'package:vinyl_app/widgets/shared/genre_breakdown_list.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';

/// Calendar-year or full-history range for play-derived aggregates.
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

class StatsRankedArtist {
  const StatsRankedArtist({
    required this.artistName,
    required this.playCount,
    required this.albumCount,
  });

  final String artistName;
  final int playCount;
  final int albumCount;
}

/// Joined snapshot of service aggregates and display names for one range.
class StatsDashboardData {
  const StatsDashboardData({
    required this.summary,
    required this.months,
    required this.years,
    required this.genres,
    required this.mostPlayed,
    required this.topArtists,
    required this.firstVinyl,
    required this.firstVinylArtistName,
    this.insights,
  });

  /// Facts for the Insights card; null hides it.
  final StatsInsights? insights;

  final CollectionSummary summary;
  final List<MonthlyPlays> months;
  final List<YearlyPlays> years;
  final List<GenreStat> genres;
  final List<StatsRankedAlbum> mostPlayed;
  final List<StatsRankedArtist> topArtists;
  final Album? firstVinyl;
  final String? firstVinylArtistName;
}

/// Loads the range-specific dashboard, resolving artist IDs once for
/// rankings rather than mixing repository lookups into the widget tree.
/// Albums, plays and genres are read once per load (not inside one database
/// transaction) and every figure is computed from that read. Monthly
/// data always covers the current year; yearly data is loaded for all-time UI.
/// This FutureProvider does not watch table changes; callers must invalidate
/// it when a write should refresh a dashboard that remains mounted.
final statsDashboardProvider = FutureProvider.autoDispose
    .family<StatsDashboardData, StatsRange>((ref, range) async {
      final service = ref.watch(statsServiceProvider);
      final artistRepository = ref.watch(artistRepositoryProvider);
      final currentYear = DateTime.now().year;
      final filteredYear = range == StatsRange.currentYear ? currentYear : null;

      // One read of albums, plays and genres feeds every figure below.
      final snapshotFuture = service.loadSnapshot();
      final artistsFuture = artistRepository.findAll();
      final snapshot = await snapshotFuture;
      final artists = await artistsFuture;

      final summary = snapshot.collectionSummary(year: filteredYear);
      final months = snapshot.playsByMonth(currentYear);
      final years = snapshot.playsByYear();
      final genres = snapshot.genreBreakdown(year: filteredYear);
      final ranked = snapshot.mostPlayedAlbums(5, year: filteredYear);
      final artistStats = snapshot.mostPlayedArtists(year: filteredYear);
      final firstVinyl = snapshot.firstVinyl();
      final insights = snapshot.insights(year: filteredYear);
      final artistsById = {
        for (final artist in artists) artist.id: artist.name,
      };
      final topArtists =
          [
            for (final item in artistStats)
              StatsRankedArtist(
                artistName: artistsById[item.artistId] ?? 'Unknown artist',
                playCount: item.playCount,
                albumCount: item.albumCount,
              ),
          ]..sort((left, right) {
            final byPlays = right.playCount.compareTo(left.playCount);
            if (byPlays != 0) return byPlays;
            return left.artistName.toLowerCase().compareTo(
              right.artistName.toLowerCase(),
            );
          });

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
        topArtists: List.unmodifiable(topArtists.take(5)),
        firstVinyl: firstVinyl,
        firstVinylArtistName: firstVinyl == null
            ? null
            : artistsById[firstVinyl.artistId] ?? 'Unknown artist',
        insights: insights,
      );
    });

/// Displays local listening statistics, charts, and rankings by range.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsRange _range = StatsRange.currentYear;

  @override
  void initState() {
    super.initState();
    ref.tutorialEvent(TutorialEvent.statsViewed);
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final dataAsync = ref.watch(statsDashboardProvider(_range));
    final tokens = context.tokens;
    final compactRangePicker =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your stats'),
        actions: [
          if (compactRangePicker)
            PopupMenuButton<StatsRange>(
              key: const Key('stats-range-menu'),
              tooltip:
                  'Stats range: ${_range == StatsRange.currentYear ? currentYear : 'All time'}',
              icon: const Icon(Icons.date_range_outlined),
              initialValue: _range,
              onSelected: (range) => setState(() => _range = range),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: StatsRange.currentYear,
                  child: Text('$currentYear'),
                ),
                const PopupMenuItem(
                  value: StatsRange.allTime,
                  child: Text('All time'),
                ),
              ],
            )
          else
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
          error: (error, stackTrace) => AppErrorState(
            key: const Key('stats-error-state'),
            title: 'Couldn’t load your stats',
            message:
                'Try loading your '
                'stats again.',
            error: error,
            stackTrace: stackTrace,
            operation: 'load stats dashboard',
            onRetry: () => ref.invalidate(statsDashboardProvider(_range)),
            retryButtonKey: const Key('stats-error-retry'),
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
          if (GoRouterState.of(context).uri.queryParameters['onboarding'] ==
              'true') {
            context.push('${routes[index]}?onboarding=true');
          } else {
            context.go(routes[index]);
          }
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
        SpotlightTarget(
          id: SpotlightId.statsSummary,
          child: _SummaryGrid(
            summary: data.summary,
            currentMonthPlays: currentMonthPlays,
            range: range,
            currentYear: currentYear,
          ),
        ),
        if (data.firstVinyl != null) ...[
          SizedBox(height: tokens.space16),
          _FirstVinylCard(
            album: data.firstVinyl!,
            artistName: data.firstVinylArtistName ?? 'Unknown artist',
          ),
        ],
        SizedBox(height: tokens.space24),
        if (data.insights case final insights?)
          if (_InsightsCard.linesFor(
            insights,
            range,
            currentYear,
          ).isNotEmpty) ...[
            _InsightsCard(
              insights: insights,
              range: range,
              currentYear: currentYear,
            ),
            SizedBox(height: tokens.space24),
          ],
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
          if (data.topArtists.isNotEmpty)
            _StatsSectionCard(
              title: 'Top artists',
              child: Column(
                children: [
                  for (var i = 0; i < data.topArtists.length; i++) ...[
                    _RankedArtistRow(rank: i + 1, item: data.topArtists[i]),
                    if (i != data.topArtists.length - 1)
                      Divider(
                        height: tokens.space24,
                        color: tokens.textMuted.withValues(alpha: 0.16),
                      ),
                  ],
                ],
              ),
            ),
          if (data.topArtists.isNotEmpty) SizedBox(height: tokens.space16),
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
        SizedBox(height: tokens.space16),
        const BadgeShelfCard(),
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
    final tiles = <Widget>[
      _StatTile(
        label: 'COLLECTION',
        value: '${summary.playedAlbums} / ${summary.totalAlbums}',
        detail: range == StatsRange.currentYear
            ? 'played in $currentYear'
            : 'played all time',
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
    ];
    // Let each row grow with text size instead of fixing card height to width.
    return Column(
      children: [
        for (var index = 0; index < tiles.length; index += 2) ...[
          if (index > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[index]),
                const SizedBox(width: 10),
                Expanded(child: tiles[index + 1]),
              ],
            ),
          ),
        ],
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
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: context.theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
              ),
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

typedef _Insight = ({IconData icon, String headline, String detail});

/// Plain-English observations built from [StatsInsights]. Each line comes
/// from one measured fact, so it can be checked against the numbers.
class _InsightsCard extends StatelessWidget {
  const _InsightsCard({
    required this.insights,
    required this.range,
    required this.currentYear,
  });

  final StatsInsights insights;
  final StatsRange range;
  final int currentYear;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _days(int count) => count == 1 ? '1 day' : '$count days';
  static String _plays(int count) => count == 1 ? '1 play' : '$count plays';

  static List<_Insight> linesFor(
    StatsInsights insights,
    StatsRange range,
    int currentYear,
  ) {
    final lines = <_Insight>[];
    final streak = insights.currentStreakDays;
    final best = insights.longestStreakDays;
    if (streak >= 2) {
      lines.add((
        icon: Icons.local_fire_department_rounded,
        headline: '${_days(streak)} in a row',
        detail: streak >= best
            ? 'Your longest listening streak yet. Play something today to '
                  'keep it going.'
            : 'Your best is ${_days(best)}. Play something today to keep '
                  'it going.',
      ));
    } else if (best >= 2) {
      lines.add((
        icon: Icons.local_fire_department_outlined,
        headline: 'Best streak: ${_days(best)}',
        detail: 'Play on two days in a row to start a new streak.',
      ));
    }

    final now = insights.periodPlays;
    final before = insights.previousPeriodPlays;
    final window = range == StatsRange.currentYear
        ? 'than this time last year'
        : 'than the 12 months before';
    if (before > 0 && now > 0) {
      final change = ((now - before) / before * 100).round();
      final detail = range == StatsRange.currentYear
          ? '${_plays(now)} so far in $currentYear, '
                '${_plays(before)} by today in ${currentYear - 1}.'
          : '${_plays(now)} in the last 12 months, '
                '${_plays(before)} in the 12 before.';
      if (change.abs() < 5) {
        lines.add((
          icon: Icons.trending_flat_rounded,
          headline: 'Listening about as much as last year',
          detail: detail,
        ));
      } else {
        lines.add((
          icon: change > 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          headline:
              '${change.abs()}% ${change > 0 ? 'more' : 'less'} '
              'listening $window',
          detail: detail,
        ));
      }
    }

    final weekday = insights.busiestWeekday;
    if (weekday != null) {
      final name = _weekdays[weekday - 1];
      lines.add((
        icon: Icons.event_rounded,
        headline: '$name is your record day',
        detail:
            '${_plays(insights.busiestWeekdayPlays)} on ${name}s'
            '${range == StatsRange.currentYear ? ' in $currentYear' : ''}, '
            'more than any other day.',
      ));
    }

    final a = insights.sideAPlays;
    final b = insights.sideBPlays;
    if (a + b >= 6 && (a >= b * 2 || b >= a * 2)) {
      final (more, less, many, few) = a > b
          ? ('A', 'B', a, b)
          : ('B', 'A', b, a);
      lines.add((
        icon: Icons.album_outlined,
        headline: few == 0
            ? 'Only ever side $more'
            : 'Side $more gets ${(many / few).round()}× the spins',
        detail:
            '${_plays(many)} of side $more and ${_plays(few)} of side $less. '
            'Flip it over sometime.',
      ));
    }

    final never = insights.neverPlayedAlbums;
    if (never > 0) {
      lines.add((
        icon: Icons.new_releases_outlined,
        headline: never == 1
            ? '1 record has never been played'
            : '$never records have never been played',
        detail:
            'Discover’s “Give these a spin” shelf is a good place to start.',
      ));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lines = linesFor(insights, range, currentYear);
    return _StatsSectionCard(
      key: const Key('stats-insights'),
      title: 'Insights',
      child: Column(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0) SizedBox(height: tokens.space12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppThemeTokens.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  ),
                  child: Icon(
                    lines[index].icon,
                    size: 20,
                    color: AppThemeTokens.accent,
                  ),
                ),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lines[index].headline,
                        style: context.theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lines[index].detail,
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsSectionCard extends StatelessWidget {
  const _StatsSectionCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
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

class _RankedArtistRow extends StatelessWidget {
  const _RankedArtistRow({required this.rank, required this.item});

  final int rank;
  final StatsRankedArtist item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final recordLabel = item.albumCount == 1 ? 'record' : 'records';
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
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
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
                item.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${item.albumCount} $recordLabel played',
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
          SizedBox(height: tokens.space16),
          FilledButton.icon(
            key: const Key('stats-log-play'),
            onPressed: () => context.push(
              GoRouterState.of(context).uri.queryParameters['onboarding'] ==
                      'true'
                  ? '${AppRoutes.logPlay}?onboarding=true'
                  : AppRoutes.logPlay,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Log a play'),
          ),
        ],
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
