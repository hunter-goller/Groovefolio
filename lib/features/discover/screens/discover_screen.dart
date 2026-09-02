import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/recommendation_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';
import 'package:vinyl_app/widgets/shared/bottom_nav_bar.dart';
import 'package:vinyl_app/widgets/shared/resilient_image.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(discoverRecommendationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: SafeArea(
        top: false,
        child: recommendations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorState(
            key: const Key('discover-error-state'),
            title: 'Couldn’t build recommendations',
            message: 'Your collection is safe. Try loading Discover again.',
            error: error,
            stackTrace: stackTrace,
            operation: 'build recommendations',
            onRetry: () => ref.invalidate(discoverRecommendationsProvider),
            retryLabel: 'Retry',
            retryButtonKey: const Key('discover-error-retry'),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(discoverRecommendationsProvider);
              await ref.read(discoverRecommendationsProvider.future);
            },
            child: _DiscoverBody(data: data),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
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

class _DiscoverBody extends StatelessWidget {
  const _DiscoverBody({required this.data});

  final DiscoverRecommendations data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final profile = data.tasteProfile;

    if (data.collectionSize == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(tokens.space16),
        children: const [_EmptyCollectionCard()],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space8,
        tokens.space16,
        tokens.space32,
      ),
      children: [
        Text(
          'Made from your shelf',
          style: context.theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: tokens.space4),
        Text(
          'Groovefolio uses only your local collection and play history to '
          'surface records worth another spin.',
          style: context.theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textMuted,
          ),
        ),
        SizedBox(height: tokens.space16),
        if (profile != null) ...[
          _TasteProfileCard(profile: profile),
          SizedBox(height: tokens.space24),
        ] else ...[
          const _LowDataCard(),
          SizedBox(height: tokens.space24),
        ],
        if (data.rediscover.isNotEmpty) ...[
          _RecommendationSection(
            title: 'Rediscover your shelf',
            subtitle: 'Albums you have played before, but not recently.',
            recommendations: data.rediscover,
          ),
          SizedBox(height: tokens.space24),
        ],
        if (data.genrePicks.isNotEmpty) ...[
          _RecommendationSection(
            title: 'From your taste',
            subtitle: 'Shelf picks that line up with what you actually play.',
            recommendations: data.genrePicks,
          ),
          SizedBox(height: tokens.space24),
        ],
        if (data.eraPicks.isNotEmpty) ...[
          _RecommendationSection(
            title: 'From your favorite era',
            subtitle:
                'More records from the decade showing up most in your plays.',
            recommendations: data.eraPicks,
          ),
          SizedBox(height: tokens.space24),
        ],
        if (profile != null && !data.hasRecommendations)
          const _NoRecommendationsCard(),
      ],
    );
  }
}

class _TasteProfileCard extends StatelessWidget {
  const _TasteProfileCard({required this.profile});

  final TasteProfile profile;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final favoriteDecade = profile.favoriteDecade;

    return Card(
      key: const Key('discover-taste-profile'),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppThemeTokens.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppThemeTokens.accent,
                  ),
                ),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your taste profile',
                        style: context.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${profile.totalPlays} logged plays across '
                        '${profile.playedAlbums} ${profile.playedAlbums == 1 ? 'album' : 'albums'}',
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.topGenres.isNotEmpty) ...[
              SizedBox(height: tokens.space16),
              Text(
                'Most-played genres',
                style: context.theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: tokens.space8),
              Wrap(
                spacing: tokens.space8,
                runSpacing: tokens.space8,
                children: [
                  for (final genre in profile.topGenres.take(4))
                    Chip(
                      label: Text('${genre.genre.name} · ${genre.playCount}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (favoriteDecade != null) ...[
              SizedBox(height: tokens.space12),
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                  SizedBox(width: tokens.space8),
                  Text(
                    'Most-played era: ${favoriteDecade}s',
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    required this.title,
    required this.subtitle,
    required this.recommendations,
  });

  final String title;
  final String subtitle;
  final List<AlbumRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: tokens.space4),
        Text(
          subtitle,
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: tokens.textMuted,
          ),
        ),
        SizedBox(height: tokens.space12),
        for (var index = 0; index < recommendations.length; index += 1) ...[
          _RecommendationCard(recommendation: recommendations[index]),
          if (index != recommendations.length - 1)
            SizedBox(height: tokens.space12),
        ],
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final AlbumRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('discover-recommendation-${recommendation.album.id}'),
        onTap: () =>
            context.push(AppRoutes.albumDetailPath(recommendation.album.id)),
        child: Padding(
          padding: EdgeInsets.all(tokens.space12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AlbumArtwork(recommendation: recommendation),
              SizedBox(width: tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.album.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: tokens.space4),
                    Text(
                      recommendation.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    SizedBox(height: tokens.space8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppThemeTokens.accent,
                          ),
                        ),
                        SizedBox(width: tokens.space8),
                        Expanded(
                          child: Text(
                            recommendation.reason,
                            style: context.theme.textTheme.bodySmall?.copyWith(
                              color: tokens.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (recommendation.genres.isNotEmpty) ...[
                      SizedBox(height: tokens.space8),
                      Text(
                        recommendation.genres.take(2).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: tokens.space4),
              Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({required this.recommendation});

  final AlbumRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final artworkPath = recommendation.album.artworkPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: SizedBox.square(
        dimension: 76,
        child: artworkPath == null || artworkPath.trim().isEmpty
            ? const _ArtworkPlaceholder()
            : ResilientImage.file(
                path: artworkPath,
                fallback: const _ArtworkPlaceholder(),
                operation: 'load Discover album artwork',
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.tokens.surfaceElevated,
      child: Icon(
        Icons.album_rounded,
        size: 34,
        color: context.tokens.textMuted,
      ),
    );
  }
}

class _LowDataCard extends StatelessWidget {
  const _LowDataCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Card(
      key: const Key('discover-low-data'),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              color: AppThemeTokens.accent,
            ),
            SizedBox(width: tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build your taste profile',
                    style: context.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    'Log a few plays and Groovefolio will start finding '
                    'neglected favorites, genre matches, and era-based picks.',
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                  SizedBox(height: tokens.space12),
                  FilledButton.icon(
                    key: const Key('discover-log-play'),
                    onPressed: () => context.push(AppRoutes.logPlay),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Log a play'),
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

class _NoRecommendationsCard extends StatelessWidget {
  const _NoRecommendationsCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Card(
      key: const Key('discover-no-recommendations'),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Column(
          children: [
            Icon(Icons.library_music_outlined, color: tokens.textMuted),
            SizedBox(height: tokens.space8),
            Text(
              'Nothing needs a nudge right now',
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.space4),
            Text(
              'Keep logging plays and adding genre or year metadata. '
              'Recommendations will refresh as your listening changes.',
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollectionCard extends StatelessWidget {
  const _EmptyCollectionCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Card(
      key: const Key('discover-empty-collection'),
      child: Padding(
        padding: EdgeInsets.all(tokens.space24),
        child: Column(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: AppThemeTokens.accent,
            ),
            SizedBox(height: tokens.space12),
            Text(
              'Add your first record',
              style: context.theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: tokens.space8),
            Text(
              'Discover learns from the records on your shelf and the plays '
              'you log. Start your collection to unlock recommendations.',
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
            SizedBox(height: tokens.space16),
            FilledButton.icon(
              key: const Key('discover-add-record'),
              onPressed: () => context.push(AppRoutes.addAlbum),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add record'),
            ),
          ],
        ),
      ),
    );
  }
}
