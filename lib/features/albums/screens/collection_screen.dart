import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/shared/album_list_tile.dart';
import 'package:vinyl_app/widgets/shared/bottom_nav_bar.dart';
import 'package:vinyl_app/widgets/shared/summary_bar.dart';
import 'package:vinyl_app/widgets/ui/empty_state.dart';
import 'package:vinyl_app/widgets/ui/filter_chip_row.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';
import 'package:vinyl_app/widgets/ui/section_header.dart';

const List<FilterChipOption<CollectionSort>> _sortOptions = [
  FilterChipOption(
    value: CollectionSort.recent,
    label: 'Recent',
    icon: Icons.schedule_rounded,
  ),
  FilterChipOption(
    value: CollectionSort.alphabetical,
    label: 'A–Z',
    icon: Icons.sort_by_alpha_rounded,
  ),
  FilterChipOption(
    value: CollectionSort.mostPlayed,
    label: 'Most played',
    icon: Icons.local_fire_department_outlined,
  ),
];

/// Main collection view.
///
/// VinylApp-018 intentionally stays thin: repository composition, searching,
/// sorting, and play-derived metadata live in the Riverpod provider layer.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(collectionFiltersProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(albumsProvider);
    await ref.read(albumsProvider.future);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(collectionFiltersProvider.notifier).setSearchQuery('');
  }

  void _openLogPlaySheet(BuildContext context) {
    final tokens = context.tokens;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tokens.background,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: const FractionallySizedBox(
            heightFactor: 0.92,
            child: LogPlayScreen(isBottomSheet: true),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(albumsProvider);
    final filters = ref.watch(collectionFiltersProvider);
    final hasAlbums = albumsAsync.when(
      data: (albums) => albums.isNotEmpty,
      loading: () => false,
      error: (error, stackTrace) => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Collection')),
      body: SafeArea(
        top: false,
        child: albumsAsync.when(
          loading: () => const _CollectionLoadingState(),
          error: (error, stackTrace) => _CollectionErrorState(
            onRetry: () => ref.invalidate(albumsProvider),
          ),
          data: (albums) => _CollectionBody(
            albums: albums,
            filters: filters,
            searchController: _searchController,
            onSearchChanged: (query) => ref
                .read(collectionFiltersProvider.notifier)
                .setSearchQuery(query),
            onClearSearch: _clearSearch,
            onSortChanged: (sort) =>
                ref.read(collectionFiltersProvider.notifier).setSort(sort),
            onRefresh: _refresh,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: hasAlbums
          ? FloatingActionButton.extended(
              onPressed: () => _openLogPlaySheet(context),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Log play'),
            )
          : null,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
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

class _CollectionBody extends StatelessWidget {
  const _CollectionBody({
    required this.albums,
    required this.filters,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSortChanged,
    required this.onRefresh,
  });

  final List<CollectionAlbum> albums;
  final CollectionFilterState filters;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<CollectionSort> onSortChanged;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasSearch = filters.normalizedSearchQuery.isNotEmpty;
    final totalPlays = albums.fold<int>(
      0,
      (total, album) => total + album.playCount,
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey<String>('collection-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        // Keep the final collection action clear of the persistent Log play FAB.
        // Scaffold already lays the body above the bottom navigation bar; this
        // extra clearance accounts for the extended FAB itself plus breathing
        // room, so Add record can scroll completely above it.
        padding: EdgeInsets.fromLTRB(
          tokens.space16,
          tokens.space8,
          tokens.space16,
          (tokens.space32 * 3) + tokens.space16,
        ),
        children: [
          if (albums.isNotEmpty || hasSearch) ...[
            _CollectionSearchField(
              controller: searchController,
              hasSearch: hasSearch,
              onChanged: onSearchChanged,
              onClear: onClearSearch,
            ),
            SizedBox(height: tokens.space16),
            FilterChipRow<CollectionSort>(
              options: _sortOptions,
              selected: filters.sort,
              onChanged: onSortChanged,
            ),
            SizedBox(height: tokens.space16),
          ],
          if (albums.isNotEmpty) ...[
            SummaryBar(recordCount: albums.length, totalPlays: totalPlays),
            SectionHeader(
              title: _sectionTitle(filters.sort),
              trailing: albums.length == 1
                  ? '1 record'
                  : '${albums.length} records',
            ),
            for (final album in albums) ...[
              AlbumListTile(
                title: album.title,
                artist: album.artistName,
                releaseYear: album.album.releaseYear,
                artworkPath: album.album.artworkPath,
                playCount: album.playCount,
                lastPlayedAt: album.lastPlayedAt,
                onTap: () => context.push(AppRoutes.albumDetailPath(album.id)),
              ),
              SizedBox(height: tokens.space8),
            ],
            SizedBox(height: tokens.space8),
            PrimaryButton(
              label: 'Add record',
              icon: Icons.add_rounded,
              onPressed: () => context.push(AppRoutes.addAlbum),
            ),
          ] else if (hasSearch)
            EmptyState(
              key: const Key('collection-no-matches'),
              icon: Icons.search_off_rounded,
              title: 'No matching records',
              subtitle:
                  'Try a different title or artist, or clear your search.',
              ctaLabel: 'Clear search',
              onCtaTap: onClearSearch,
            )
          else
            EmptyState(
              key: const Key('collection-empty-state'),
              icon: Icons.album_outlined,
              title: 'Your collection is empty',
              subtitle:
                  'Add your first record and Vinyl App will start building your listening history.',
              ctaLabel: 'Add your first record',
              onCtaTap: () => context.push(AppRoutes.addAlbum),
            ),
        ],
      ),
    );
  }

  String _sectionTitle(CollectionSort sort) {
    return switch (sort) {
      CollectionSort.recent => 'Recently played',
      CollectionSort.alphabetical => 'Albums A–Z',
      CollectionSort.mostPlayed => 'Most played',
    };
  }
}

class _CollectionSearchField extends StatelessWidget {
  const _CollectionSearchField({
    required this.controller,
    required this.hasSearch,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasSearch;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('collection-search-field'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search records or artists',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasSearch
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
      ),
    );
  }
}

class _CollectionLoadingState extends StatelessWidget {
  const _CollectionLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _CollectionErrorState extends StatelessWidget {
  const _CollectionErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Couldn’t load your collection',
      subtitle: 'Something went wrong while reading your local collection.',
      ctaLabel: 'Try again',
      onCtaTap: onRetry,
    );
  }
}
