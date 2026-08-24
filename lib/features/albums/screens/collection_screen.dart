import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/album_delete_flow.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';
import 'package:vinyl_app/widgets/shared/album_list_tile.dart';
import 'package:vinyl_app/widgets/shared/bottom_nav_bar.dart';
import 'package:vinyl_app/widgets/ui/empty_state.dart';
import 'package:vinyl_app/widgets/ui/filter_chip_row.dart';
import 'package:vinyl_app/widgets/ui/section_header.dart';

const List<FilterChipOption<CollectionSort>> _sortOptions = [
  FilterChipOption(value: CollectionSort.recent, label: 'Recent'),
  FilterChipOption(value: CollectionSort.alphabetical, label: 'A–Z'),
  FilterChipOption(value: CollectionSort.mostPlayed, label: 'Most played'),
];

/// Main collection view aligned with the approved compact dark-mode mockup.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  late final TextEditingController _searchController;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(collectionFiltersProvider).searchQuery,
    );
    _showSearch = _searchController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(albumsProvider);
    ref.invalidate(albumGenresProvider);
    await ref.read(albumsProvider.future);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(collectionFiltersProvider.notifier).setSearchQuery('');
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) _clearSearch();
  }

  Future<void> _showGenreFilter() async {
    final genres = await ref.read(genresProvider.future);
    if (!mounted) return;

    final currentGenre = ref.read(collectionFiltersProvider).genre;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final tokens = sheetContext.tokens;
        final availableHeight = MediaQuery.sizeOf(sheetContext).height;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: availableHeight * 0.72),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space16,
              0,
              tokens.space16,
              tokens.space24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter by genre',
                  style: sheetContext.theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: tokens.space12),
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('collection-genre-filter-scroll'),
                    child: Wrap(
                      spacing: tokens.space8,
                      runSpacing: tokens.space8,
                      children: [
                        ChoiceChip(
                          label: const Text('All genres'),
                          selected: currentGenre == null,
                          onSelected: (_) => Navigator.of(sheetContext).pop(''),
                        ),
                        for (final genre in genres)
                          ChoiceChip(
                            label: Text(genre.name),
                            selected:
                                currentGenre?.toLowerCase() ==
                                genre.name.toLowerCase(),
                            onSelected: (_) =>
                                Navigator.of(sheetContext).pop(genre.name),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    ref
        .read(collectionFiltersProvider.notifier)
        .setGenre(selected.isEmpty ? null : selected);
  }

  void _openLogPlaySheet(BuildContext context) {
    final tokens = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tokens.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const FractionallySizedBox(
          heightFactor: 0.92,
          child: LogPlayScreen(isBottomSheet: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(albumsProvider);
    final filters = ref.watch(collectionFiltersProvider);
    final hasAlbums = albumsAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My collection'),
        actions: [
          if (hasAlbums)
            IconButton(
              tooltip: 'Log a play',
              onPressed: () => _openLogPlaySheet(context),
              icon: const Icon(Icons.play_circle_outline_rounded),
            ),
          IconButton(
            tooltip: _showSearch ? 'Close search' : 'Search collection',
            onPressed: _toggleSearch,
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: albumsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _CollectionErrorState(
            onRetry: () => ref.invalidate(albumsProvider),
          ),
          data: (albums) {
            final selectedGenre = filters.genre;
            final visibleAlbums = selectedGenre == null
                ? albums
                : albums
                      .where((album) {
                        final assignedGenres =
                            ref.watch(albumGenresProvider(album.id)).value ??
                            const <Genre>[];
                        return assignedGenres.any(
                          (genre) =>
                              genre.name.toLowerCase() ==
                              selectedGenre.toLowerCase(),
                        );
                      })
                      .toList(growable: false);

            return _CollectionBody(
              albums: visibleAlbums,
              filters: filters,
              showSearch: _showSearch,
              searchController: _searchController,
              selectedGenre: filters.genre,
              onSearchChanged: (query) => ref
                  .read(collectionFiltersProvider.notifier)
                  .setSearchQuery(query),
              onClearSearch: _clearSearch,
              onSortChanged: (sort) =>
                  ref.read(collectionFiltersProvider.notifier).setSort(sort),
              onGenreFilterPressed: _showGenreFilter,
              onRefresh: _refresh,
            );
          },
        ),
      ),
      floatingActionButton: hasAlbums && !_showSearch
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.addAlbum),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add record'),
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

class _CollectionAlbumTile extends ConsumerWidget {
  const _CollectionAlbumTile({required this.album});

  final CollectionAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres =
        ref
            .watch(albumGenresProvider(album.id))
            .value
            ?.map((genre) => genre.name)
            .toList(growable: false) ??
        const <String>[];

    return AlbumListTile(
      title: album.title,
      artist: album.artistName,
      releaseYear: album.album.releaseYear,
      artworkPath: album.album.artworkPath,
      playCount: album.playCount,
      lastPlayedAt: album.lastPlayedAt,
      genres: genres,
      onTap: () => context.push(AppRoutes.albumDetailPath(album.id)),
      onLongPress: () => _showQuickActions(context, ref),
    );
  }

  Future<void> _showQuickActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_CollectionAlbumAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sheetContext.tokens.space16,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sheetContext.theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ListTile(
            key: const Key('collection-quick-edit'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit record'),
            onTap: () =>
                Navigator.of(sheetContext).pop(_CollectionAlbumAction.edit),
          ),
          ListTile(
            key: const Key('collection-quick-delete'),
            leading: Icon(
              Icons.delete_outline_rounded,
              color: sheetContext.theme.colorScheme.error,
            ),
            title: Text(
              'Delete record',
              style: TextStyle(color: sheetContext.theme.colorScheme.error),
            ),
            onTap: () =>
                Navigator.of(sheetContext).pop(_CollectionAlbumAction.delete),
          ),
          SizedBox(height: sheetContext.tokens.space8),
        ],
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case _CollectionAlbumAction.edit:
        await context.push(AppRoutes.editAlbumPath(album.id));
        break;
      case _CollectionAlbumAction.delete:
        await confirmAndDeleteAlbum(context, ref, album.id);
        break;
    }
  }
}

enum _CollectionAlbumAction { edit, delete }

class _CollectionBody extends StatelessWidget {
  const _CollectionBody({
    required this.albums,
    required this.filters,
    required this.showSearch,
    required this.searchController,
    required this.selectedGenre,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSortChanged,
    required this.onGenreFilterPressed,
    required this.onRefresh,
  });

  final List<CollectionAlbum> albums;
  final CollectionFilterState filters;
  final bool showSearch;
  final TextEditingController searchController;
  final String? selectedGenre;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<CollectionSort> onSortChanged;
  final VoidCallback onGenreFilterPressed;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasSearch = filters.normalizedSearchQuery.isNotEmpty;
    final totalPlays = albums.fold<int>(
      0,
      (sum, album) => sum + album.playCount,
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey<String>('collection-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          tokens.space16,
          tokens.space4,
          tokens.space16,
          104,
        ),
        children: [
          if (showSearch) ...[
            _CollectionSearchField(
              controller: searchController,
              hasSearch: hasSearch,
              onChanged: onSearchChanged,
              onClear: onClearSearch,
            ),
            SizedBox(height: tokens.space12),
          ],
          if (albums.isNotEmpty || hasSearch || selectedGenre != null) ...[
            _CollectionSummaryPills(
              recordCount: albums.length,
              totalPlays: totalPlays,
            ),
            SizedBox(height: tokens.space12),
            _CollectionFilterControls(
              selectedSort: filters.sort,
              selectedGenre: selectedGenre,
              onSortChanged: onSortChanged,
              onGenrePressed: onGenreFilterPressed,
            ),
            SizedBox(height: tokens.space16),
          ],
          if (albums.isNotEmpty) ...[
            SectionHeader(
              title: _sectionTitle(filters.sort),
              trailing: albums.length == 1
                  ? '1 record'
                  : '${albums.length} records',
            ),
            for (var index = 0; index < albums.length; index++) ...[
              _CollectionAlbumTile(album: albums[index]),
              if (index != albums.length - 1)
                Divider(
                  indent: 70,
                  color: tokens.textMuted.withValues(alpha: 0.14),
                ),
            ],
          ] else if (selectedGenre != null)
            EmptyState(
              key: const Key('collection-no-genre-matches'),
              icon: Icons.filter_alt_off_rounded,
              title: 'No $selectedGenre records',
              subtitle: 'Choose another genre to see more of your collection.',
              ctaLabel: 'Choose another genre',
              onCtaTap: onGenreFilterPressed,
            )
          else if (hasSearch)
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
                  'Add your first record and Groovefolio will start building your listening history.',
              ctaLabel: 'Add your first record',
              onCtaTap: () => context.push(AppRoutes.addAlbum),
            ),
        ],
      ),
    );
  }

  String _sectionTitle(CollectionSort sort) => switch (sort) {
    CollectionSort.recent => 'Recently played',
    CollectionSort.alphabetical => 'Albums A–Z',
    CollectionSort.mostPlayed => 'Most played',
  };
}

class _CollectionFilterControls extends StatelessWidget {
  const _CollectionFilterControls({
    required this.selectedSort,
    required this.selectedGenre,
    required this.onSortChanged,
    required this.onGenrePressed,
  });

  final CollectionSort selectedSort;
  final String? selectedGenre;
  final ValueChanged<CollectionSort> onSortChanged;
  final VoidCallback onGenrePressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Keep the primary sort controls anchored at the left. The row remains
    // horizontally scrollable on narrower phones, but changing the genre must
    // never auto-scroll Recent/A-Z/Most played off-screen.
    return SingleChildScrollView(
      key: const Key('collection-filter-scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in _sortOptions) ...[
            ChoiceChip(
              selected: option.value == selectedSort,
              showCheckmark: false,
              onSelected: (_) => onSortChanged(option.value),
              label: Text(option.label),
              selectedColor: AppThemeTokens.accent,
              backgroundColor: tokens.surface,
              side: BorderSide(
                color: option.value == selectedSort
                    ? AppThemeTokens.accent
                    : tokens.textMuted.withValues(alpha: 0.24),
              ),
              labelStyle: context.theme.textTheme.labelLarge?.copyWith(
                color: option.value == selectedSort
                    ? Colors.black
                    : tokens.textMuted,
                fontWeight: option.value == selectedSort
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
            SizedBox(width: tokens.space8),
          ],
          ChoiceChip(
            key: const Key('collection-genre-filter'),
            selected: selectedGenre != null,
            showCheckmark: false,
            onSelected: (_) => onGenrePressed(),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: Text(
                selectedGenre ?? 'Genre',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            selectedColor: AppThemeTokens.accent,
            backgroundColor: tokens.surface,
            side: BorderSide(
              color: selectedGenre != null
                  ? AppThemeTokens.accent
                  : tokens.textMuted.withValues(alpha: 0.24),
            ),
            labelStyle: context.theme.textTheme.labelLarge?.copyWith(
              color: selectedGenre != null ? Colors.black : tokens.textMuted,
              fontWeight: selectedGenre != null
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionSummaryPills extends StatelessWidget {
  const _CollectionSummaryPills({
    required this.recordCount,
    required this.totalPlays,
  });

  final int recordCount;
  final int totalPlays;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: tokens.space8,
      runSpacing: tokens.space8,
      children: [
        _SummaryPill(
          icon: Icons.album_outlined,
          text: '$recordCount ${recordCount == 1 ? 'record' : 'records'}',
        ),
        _SummaryPill(
          icon: Icons.play_circle_outline_rounded,
          text: '$totalPlays ${totalPlays == 1 ? 'play' : 'plays'}',
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: context.theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              text,
              style: context.theme.textTheme.labelMedium?.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
      autofocus: true,
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
