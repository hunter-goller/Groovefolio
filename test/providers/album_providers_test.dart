import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  const miles = Artist(
    id: 'artist-miles',
    name: 'Miles Davis',
    createdAt: '2026-08-01T00:00:00.000Z',
  );
  const coltrane = Artist(
    id: 'artist-coltrane',
    name: 'John Coltrane',
    createdAt: '2026-08-01T00:00:00.000Z',
  );
  const kindOfBlue = Album(
    id: 'album-kind-of-blue',
    title: 'Kind of Blue',
    artistId: 'artist-miles',
    releaseYear: 1959,
    createdAt: '2026-08-01T00:00:00.000Z',
  );
  const blueTrain = Album(
    id: 'album-blue-train',
    title: 'Blue Train',
    artistId: 'artist-coltrane',
    releaseYear: 1957,
    createdAt: '2026-08-02T00:00:00.000Z',
  );
  const sketches = Album(
    id: 'album-sketches',
    title: 'Sketches of Spain',
    artistId: 'artist-miles',
    releaseYear: 1960,
    createdAt: '2026-08-03T00:00:00.000Z',
  );

  group('collectionFiltersProvider', () {
    test('defaults to recent with no search query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filters = container.read(collectionFiltersProvider);

      expect(filters.sort, CollectionSort.recent);
      expect(filters.searchQuery, isEmpty);
    });

    test('updates search and sort state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(collectionFiltersProvider.notifier);
      notifier.setSearchQuery('  miles  ');
      notifier.setSort(CollectionSort.alphabetical);

      final filters = container.read(collectionFiltersProvider);
      expect(filters.normalizedSearchQuery, 'miles');
      expect(filters.sort, CollectionSort.alphabetical);
    });
  });

  group('albumsProvider', () {
    test('returns UI-ready rows sorted by last played by default', () async {
      final albumRepository = _FakeAlbumRepository([
        kindOfBlue,
        blueTrain,
        sketches,
      ]);
      final playRepository = _FakePlayRepository([
        _play('play-1', kindOfBlue.id, '2026-08-10T12:00:00.000Z'),
        _play('play-2', kindOfBlue.id, '2026-08-11T12:00:00.000Z'),
        _play('play-3', blueTrain.id, '2026-08-12T12:00:00.000Z'),
      ]);
      final container = _container(
        albumRepository: albumRepository,
        artistRepository: _FakeArtistRepository([miles, coltrane]),
        playRepository: playRepository,
      );
      addTearDown(container.dispose);

      final albums = await container.read(albumsProvider.future);

      expect(albums.map((album) => album.id), [
        blueTrain.id,
        kindOfBlue.id,
        sketches.id,
      ]);
      expect(albums[0].artistName, 'John Coltrane');
      expect(albums[0].playCount, 1);
      expect(
        albums[0].lastPlayedAt,
        DateTime.parse('2026-08-12T12:00:00.000Z'),
      );
      expect(albums[1].playCount, 2);
      expect(albums[2].playCount, 0);
      expect(albums[2].lastPlayedAt, isNull);
    });

    test('reacts to collection search and alphabetical sort', () async {
      final container = _container(
        albumRepository: _FakeAlbumRepository([
          kindOfBlue,
          blueTrain,
          sketches,
        ]),
        artistRepository: _FakeArtistRepository([miles, coltrane]),
        playRepository: _FakePlayRepository(const []),
      );
      addTearDown(container.dispose);
      final subscription = container.listen(albumsProvider, (_, _) {});
      addTearDown(subscription.close);

      container
          .read(collectionFiltersProvider.notifier)
          .setSearchQuery('miles');
      container
          .read(collectionFiltersProvider.notifier)
          .setSort(CollectionSort.alphabetical);

      final albums = await container.read(albumsProvider.future);

      expect(albums.map((album) => album.title), [
        'Kind of Blue',
        'Sketches of Spain',
      ]);
    });

    test('sorts most played descending', () async {
      final container = _container(
        albumRepository: _FakeAlbumRepository([
          kindOfBlue,
          blueTrain,
          sketches,
        ]),
        artistRepository: _FakeArtistRepository([miles, coltrane]),
        playRepository: _FakePlayRepository([
          _play('play-1', kindOfBlue.id, '2026-08-10T12:00:00.000Z'),
          _play('play-2', blueTrain.id, '2026-08-10T12:00:00.000Z'),
          _play('play-3', blueTrain.id, '2026-08-11T12:00:00.000Z'),
          _play('play-4', blueTrain.id, '2026-08-12T12:00:00.000Z'),
        ]),
      );
      addTearDown(container.dispose);
      final subscription = container.listen(albumsProvider, (_, _) {});
      addTearDown(subscription.close);

      container
          .read(collectionFiltersProvider.notifier)
          .setSort(CollectionSort.mostPlayed);

      final albums = await container.read(albumsProvider.future);

      expect(albums.first.id, blueTrain.id);
      expect(albums.first.playCount, 3);
      expect(albums[1].id, kindOfBlue.id);
    });
  });

  group('lookup providers', () {
    test('albumProvider delegates to AlbumRepository', () async {
      final container = _container(
        albumRepository: _FakeAlbumRepository([kindOfBlue]),
        artistRepository: _FakeArtistRepository([miles]),
        playRepository: _FakePlayRepository(const []),
      );
      addTearDown(container.dispose);

      final album = await container.read(albumProvider(kindOfBlue.id).future);

      expect(album, kindOfBlue);
    });

    test(
      'albumDetailProvider composes album, artist, and play history',
      () async {
        final container = _container(
          albumRepository: _FakeAlbumRepository([kindOfBlue]),
          artistRepository: _FakeArtistRepository([miles]),
          playRepository: _FakePlayRepository([
            _play('play-older', kindOfBlue.id, '2026-08-10T12:00:00.000Z'),
            _play('play-newer', kindOfBlue.id, '2026-08-12T12:00:00.000Z'),
          ]),
        );
        addTearDown(container.dispose);

        final detail = await container.read(
          albumDetailProvider(kindOfBlue.id).future,
        );

        expect(detail, isNotNull);
        expect(detail!.album, kindOfBlue);
        expect(detail.artist, miles);
        expect(detail.playCount, 2);
        expect(detail.plays.first.id, 'play-newer');
        expect(detail.lastPlayedAt, DateTime.parse('2026-08-12T12:00:00.000Z'));
      },
    );

    test('albumDetailProvider returns null for an unknown album', () async {
      final container = _container(
        albumRepository: _FakeAlbumRepository([kindOfBlue]),
        artistRepository: _FakeArtistRepository([miles]),
        playRepository: _FakePlayRepository(const []),
      );
      addTearDown(container.dispose);

      final detail = await container.read(
        albumDetailProvider('missing').future,
      );

      expect(detail, isNull);
    });

    test('playCountProvider delegates to PlayRepository', () async {
      final container = _container(
        albumRepository: _FakeAlbumRepository([kindOfBlue]),
        artistRepository: _FakeArtistRepository([miles]),
        playRepository: _FakePlayRepository([
          _play('play-1', kindOfBlue.id, '2026-08-10T12:00:00.000Z'),
          _play('play-2', kindOfBlue.id, '2026-08-11T12:00:00.000Z'),
        ]),
      );
      addTearDown(container.dispose);

      final count = await container.read(
        playCountProvider(kindOfBlue.id).future,
      );

      expect(count, 2);
    });

    test('recentlyPlayedProvider delegates to PlayRepository', () async {
      final playRepository = _FakePlayRepository(const []);
      playRepository.recentlyPlayed = [blueTrain, kindOfBlue];
      final container = _container(
        albumRepository: _FakeAlbumRepository([kindOfBlue, blueTrain]),
        artistRepository: _FakeArtistRepository([miles, coltrane]),
        playRepository: playRepository,
      );
      addTearDown(container.dispose);

      final albums = await container.read(recentlyPlayedProvider.future);

      expect(albums, [blueTrain, kindOfBlue]);
      expect(playRepository.lastRecentlyPlayedLimit, 10);
    });
  });

  group('albumMutationsProvider', () {
    test(
      'create invalidates albumsProvider and exposes the new album',
      () async {
        final albumRepository = _FakeAlbumRepository([kindOfBlue]);
        final container = _container(
          albumRepository: albumRepository,
          artistRepository: _FakeArtistRepository([miles, coltrane]),
          playRepository: _FakePlayRepository(const []),
        );
        addTearDown(container.dispose);
        final subscription = container.listen(albumsProvider, (_, _) {});
        addTearDown(subscription.close);

        expect(
          (await container.read(
            albumsProvider.future,
          )).map((album) => album.id),
          [kindOfBlue.id],
        );

        final created = await container
            .read(albumMutationsProvider.notifier)
            .create(title: 'Blue Train', artistId: coltrane.id);

        final refreshed = await container.read(albumsProvider.future);
        expect(refreshed.map((album) => album.id), contains(created.id));
      },
    );

    test('update invalidates album and collection providers', () async {
      final albumRepository = _FakeAlbumRepository([kindOfBlue]);
      final container = _container(
        albumRepository: albumRepository,
        artistRepository: _FakeArtistRepository([miles]),
        playRepository: _FakePlayRepository(const []),
      );
      addTearDown(container.dispose);
      final listSubscription = container.listen(albumsProvider, (_, _) {});
      final albumSubscription = container.listen(
        albumProvider(kindOfBlue.id),
        (_, _) {},
      );
      addTearDown(listSubscription.close);
      addTearDown(albumSubscription.close);

      final updatedAlbum = kindOfBlue.copyWith(title: 'Kind of Blue Deluxe');
      final updated = await container
          .read(albumMutationsProvider.notifier)
          .update(updatedAlbum);

      expect(updated, isTrue);
      expect(
        (await container.read(albumProvider(kindOfBlue.id).future))?.title,
        'Kind of Blue Deluxe',
      );
      expect(
        (await container.read(albumsProvider.future)).single.title,
        'Kind of Blue Deluxe',
      );
    });

    test('delete invalidates albumsProvider and removes the album', () async {
      final albumRepository = _FakeAlbumRepository([kindOfBlue, blueTrain]);
      final container = _container(
        albumRepository: albumRepository,
        artistRepository: _FakeArtistRepository([miles, coltrane]),
        playRepository: _FakePlayRepository(const []),
      );
      addTearDown(container.dispose);
      final subscription = container.listen(albumsProvider, (_, _) {});
      addTearDown(subscription.close);

      final deleted = await container
          .read(albumMutationsProvider.notifier)
          .delete(blueTrain.id);

      expect(deleted, 1);
      expect(
        (await container.read(albumsProvider.future)).map((album) => album.id),
        [kindOfBlue.id],
      );
    });
  });
}

ProviderContainer _container({
  required IAlbumRepository albumRepository,
  required IArtistRepository artistRepository,
  required IPlayRepository playRepository,
}) {
  return ProviderContainer(
    overrides: [
      albumRepositoryProvider.overrideWithValue(albumRepository),
      artistRepositoryProvider.overrideWithValue(artistRepository),
      playRepositoryProvider.overrideWithValue(playRepository),
    ],
  );
}

Play _play(String id, String albumId, String playedAt) {
  return Play(
    id: id,
    albumId: albumId,
    playedAt: playedAt,
    sidePlayed: SidePlayed.full,
    createdAt: playedAt,
  );
}

class _FakeAlbumRepository implements IAlbumRepository {
  _FakeAlbumRepository(Iterable<Album> albums)
    : _albums = {for (final album in albums) album.id: album};

  final Map<String, Album> _albums;
  int _nextId = 1;

  @override
  Future<List<Album>> findAll() async => List.unmodifiable(_albums.values);

  @override
  Future<Album?> findById(String id) async => _albums[id];

  @override
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) async {
    final album = Album(
      id: 'created-${_nextId++}',
      title: title.trim(),
      artistId: artistId.trim(),
      releaseYear: releaseYear,
      label: label,
      artworkPath: artworkPath,
      purchaseDate: purchaseDate?.toUtc().toIso8601String(),
      purchasePriceCents: purchasePriceCents,
      createdAt: '2026-08-12T00:00:00.000Z',
    );
    _albums[album.id] = album;
    return album;
  }

  @override
  Future<bool> update(Album album) async {
    if (!_albums.containsKey(album.id)) {
      return false;
    }
    _albums[album.id] = album;
    return true;
  }

  @override
  Future<int> delete(String id) async => _albums.remove(id) == null ? 0 : 1;

  @override
  Future<List<Album>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return findAll();
    }

    const artistNames = {
      'artist-miles': 'miles davis',
      'artist-coltrane': 'john coltrane',
    };

    return _albums.values.where((album) {
      return album.title.toLowerCase().contains(normalized) ||
          (artistNames[album.artistId]?.contains(normalized) ?? false);
    }).toList();
  }
}

class _FakeArtistRepository implements IArtistRepository {
  _FakeArtistRepository(Iterable<Artist> artists)
    : _artists = {for (final artist in artists) artist.id: artist};

  final Map<String, Artist> _artists;

  @override
  Future<List<Artist>> findAll() async => List.unmodifiable(_artists.values);

  @override
  Future<Artist?> findById(String id) async => _artists[id];

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
  _FakePlayRepository(Iterable<Play> plays) : _plays = List.of(plays);

  final List<Play> _plays;
  List<Album> recentlyPlayed = const [];
  int? lastRecentlyPlayedLimit;

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(_plays);

  @override
  Future<int> getPlayCountByAlbum(String albumId) async {
    return _plays.where((play) => play.albumId == albumId).length;
  }

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async {
    lastRecentlyPlayedLimit = limit;
    return recentlyPlayed.take(limit).toList();
  }

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    return _plays.where((play) => play.albumId == albumId).toList();
  }
}
