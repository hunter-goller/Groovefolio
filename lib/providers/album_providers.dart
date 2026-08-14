import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

/// Sort modes supported by the Collection screen with the current schema.
enum CollectionSort { recent, alphabetical, mostPlayed }

/// User-controlled Collection query state.
class CollectionFilterState {
  const CollectionFilterState({
    this.searchQuery = '',
    this.sort = CollectionSort.recent,
  });

  final String searchQuery;
  final CollectionSort sort;

  String get normalizedSearchQuery => searchQuery.trim();

  CollectionFilterState copyWith({String? searchQuery, CollectionSort? sort}) {
    return CollectionFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      sort: sort ?? this.sort,
    );
  }
}

/// UI-ready Collection row assembled from repository data.
///
/// Drift's Album row intentionally stores only artistId. The Collection screen
/// also needs the Artist plus play-derived values, so the provider layer builds
/// this view model instead of forcing widgets to join repository data.
class CollectionAlbum {
  const CollectionAlbum({
    required this.album,
    required this.artist,
    required this.playCount,
    required this.lastPlayedAt,
  });

  final Album album;
  final Artist artist;
  final int playCount;
  final DateTime? lastPlayedAt;

  String get id => album.id;
  String get title => album.title;
  String get artistName => artist.name;
}

/// Collection search/sort state owned by Riverpod rather than widget-local
/// state.
class CollectionFilters extends Notifier<CollectionFilterState> {
  @override
  CollectionFilterState build() => const CollectionFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSort(CollectionSort sort) {
    state = state.copyWith(sort: sort);
  }

  void reset() {
    state = const CollectionFilterState();
  }
}

final collectionFiltersProvider =
    NotifierProvider<CollectionFilters, CollectionFilterState>(
      CollectionFilters.new,
    );

/// All Collection rows after the active search and sort are applied.
///
/// This provider intentionally composes repository APIs instead of reading
/// Drift directly. Artists and plays are loaded once and indexed in memory so
/// building a Collection does not perform a query per album.
final albumsProvider = FutureProvider.autoDispose<List<CollectionAlbum>>((
  ref,
) async {
  final filters = ref.watch(collectionFiltersProvider);
  final albumRepository = ref.watch(albumRepositoryProvider);
  final artistRepository = ref.watch(artistRepositoryProvider);
  final playRepository = ref.watch(playRepositoryProvider);

  final albumRows = filters.normalizedSearchQuery.isEmpty
      ? await albumRepository.findAll()
      : await albumRepository.search(filters.normalizedSearchQuery);

  if (albumRows.isEmpty) {
    return const [];
  }

  final artistsFuture = artistRepository.findAll();
  final playsFuture = playRepository.findAll();
  final artists = await artistsFuture;
  final plays = await playsFuture;

  final artistsById = {for (final artist in artists) artist.id: artist};
  final playSummaries = _summarizePlays(plays);

  final collectionAlbums = <CollectionAlbum>[];
  for (final album in albumRows) {
    final artist = artistsById[album.artistId];
    if (artist == null) {
      throw StateError(
        'Album ${album.id} references missing artist ${album.artistId}.',
      );
    }

    final summary = playSummaries[album.id];
    collectionAlbums.add(
      CollectionAlbum(
        album: album,
        artist: artist,
        playCount: summary?.count ?? 0,
        lastPlayedAt: summary?.lastPlayedAt,
      ),
    );
  }

  _sortCollection(collectionAlbums, filters.sort);
  return collectionAlbums;
});

/// Album search rows for selection flows such as Log Play.
///
/// Unlike [albumsProvider], this provider is independent of Collection filter
/// state so a search performed in Log Play never changes the Collection screen.
final albumSearchProvider = FutureProvider.autoDispose
    .family<List<CollectionAlbum>, String>((ref, query) async {
      final normalizedQuery = query.trim();
      final albumRepository = ref.watch(albumRepositoryProvider);
      final artistRepository = ref.watch(artistRepositoryProvider);
      final playRepository = ref.watch(playRepositoryProvider);

      final albumRows = normalizedQuery.isEmpty
          ? await albumRepository.findAll()
          : await albumRepository.search(normalizedQuery);

      if (albumRows.isEmpty) {
        return const [];
      }

      final artistsFuture = artistRepository.findAll();
      final playsFuture = playRepository.findAll();
      final artists = await artistsFuture;
      final plays = await playsFuture;

      final artistsById = {for (final artist in artists) artist.id: artist};
      final playSummaries = _summarizePlays(plays);
      final rows = <CollectionAlbum>[];

      for (final album in albumRows) {
        final artist = artistsById[album.artistId];
        if (artist == null) {
          throw StateError(
            'Album ${album.id} references missing artist ${album.artistId}.',
          );
        }

        final summary = playSummaries[album.id];
        rows.add(
          CollectionAlbum(
            album: album,
            artist: artist,
            playCount: summary?.count ?? 0,
            lastPlayedAt: summary?.lastPlayedAt,
          ),
        );
      }

      rows.sort(_compareTitles);
      return rows;
    });

/// Single album lookup used by details/edit flows.
final albumProvider = FutureProvider.autoDispose.family<Album?, String>((
  ref,
  id,
) {
  final normalizedId = id.trim();
  if (normalizedId.isEmpty) {
    return Future.value(null);
  }

  return ref.watch(albumRepositoryProvider).findById(normalizedId);
});

/// Most recently played distinct albums, newest first.
final recentlyPlayedProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  return ref.watch(playRepositoryProvider).getRecentlyPlayed(10);
});

/// Total number of logged plays for one album.
final playCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  albumId,
) {
  final normalizedId = albumId.trim();
  if (normalizedId.isEmpty) {
    return Future.value(0);
  }

  return ref.watch(playRepositoryProvider).getPlayCountByAlbum(normalizedId);
});

/// Album write operations plus the provider invalidation required to keep UI
/// data fresh after create/update/delete actions.
///
/// This also gives VinylApp-019 a mutation entry point without making screens
/// call repositories directly.
class AlbumMutations extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) async {
    state = const AsyncLoading<void>();

    try {
      final created = await ref
          .read(albumRepositoryProvider)
          .create(
            title: title,
            artistId: artistId,
            releaseYear: releaseYear,
            label: label,
            artworkPath: artworkPath,
            purchaseDate: purchaseDate,
            purchasePriceCents: purchasePriceCents,
          );
      _invalidateAlbumData(created.id);
      state = const AsyncData<void>(null);
      return created;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> update(Album album) async {
    state = const AsyncLoading<void>();

    try {
      final updated = await ref.read(albumRepositoryProvider).update(album);
      if (updated) {
        _invalidateAlbumData(album.id);
      }
      state = const AsyncData<void>(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  Future<int> delete(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Album ID cannot be empty.');
    }

    state = const AsyncLoading<void>();

    try {
      final deleted = await ref
          .read(albumRepositoryProvider)
          .delete(normalizedId);
      if (deleted > 0) {
        _invalidateAlbumData(normalizedId);
      }
      state = const AsyncData<void>(null);
      return deleted;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  void _invalidateAlbumData(String albumId) {
    ref.invalidate(albumsProvider);
    ref.invalidate(albumProvider(albumId));
    ref.invalidate(recentlyPlayedProvider);
    ref.invalidate(playCountProvider(albumId));
  }
}

final albumMutationsProvider =
    NotifierProvider<AlbumMutations, AsyncValue<void>>(AlbumMutations.new);

class _PlaySummary {
  const _PlaySummary({required this.count, required this.lastPlayedAt});

  final int count;
  final DateTime? lastPlayedAt;
}

Map<String, _PlaySummary> _summarizePlays(List<Play> plays) {
  final counts = <String, int>{};
  final latest = <String, DateTime>{};

  for (final play in plays) {
    counts.update(play.albumId, (count) => count + 1, ifAbsent: () => 1);

    final playedAt = DateTime.tryParse(play.playedAt);
    if (playedAt == null) {
      continue;
    }

    final current = latest[play.albumId];
    if (current == null || playedAt.isAfter(current)) {
      latest[play.albumId] = playedAt;
    }
  }

  return {
    for (final entry in counts.entries)
      entry.key: _PlaySummary(
        count: entry.value,
        lastPlayedAt: latest[entry.key],
      ),
  };
}

void _sortCollection(List<CollectionAlbum> albums, CollectionSort sort) {
  switch (sort) {
    case CollectionSort.recent:
      albums.sort((a, b) {
        final recentComparison = _compareNullableDatesDescending(
          a.lastPlayedAt,
          b.lastPlayedAt,
        );
        if (recentComparison != 0) {
          return recentComparison;
        }
        return _compareTitles(a, b);
      });
      return;
    case CollectionSort.alphabetical:
      albums.sort(_compareTitles);
      return;
    case CollectionSort.mostPlayed:
      albums.sort((a, b) {
        final playComparison = b.playCount.compareTo(a.playCount);
        if (playComparison != 0) {
          return playComparison;
        }

        final recentComparison = _compareNullableDatesDescending(
          a.lastPlayedAt,
          b.lastPlayedAt,
        );
        if (recentComparison != 0) {
          return recentComparison;
        }
        return _compareTitles(a, b);
      });
      return;
  }
}

int _compareNullableDatesDescending(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

int _compareTitles(CollectionAlbum a, CollectionAlbum b) {
  final titleComparison = a.title.toLowerCase().compareTo(
    b.title.toLowerCase(),
  );
  if (titleComparison != 0) {
    return titleComparison;
  }
  return a.id.compareTo(b.id);
}
