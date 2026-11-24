import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/types/side_played.dart';

/// The dashboard must read each table once per load, however many figures it
/// shows, and never query genres album by album.
void main() {
  for (final range in StatsRange.values) {
    test('$range loads albums, plays and genres once', () async {
      final albums = _Albums();
      final plays = _Plays();
      final genres = _Genres();
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(albums),
          playRepositoryProvider.overrideWithValue(plays),
          genreRepositoryProvider.overrideWithValue(genres),
          artistRepositoryProvider.overrideWithValue(_Artists()),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(statsDashboardProvider(range).future);

      expect(plays.findAllCalls, 1);
      expect(albums.findAllCalls, 1);
      expect(genres.findAllByAlbumCalls, 1);
      expect(genres.findByAlbumCalls, 0);
      expect(data.summary.totalPlays, 3);
      expect(data.genres.single.genre.name, 'Jazz');
      expect(data.mostPlayed.first.artistName, 'Artist');
      expect(data.topArtists.single.playCount, 3);
    });
  }
}

final _now = DateTime.now().toUtc();

Album _album(String id) => Album(
  id: id,
  title: 'Album $id',
  artistId: 'artist-1',
  createdAt: _now.toIso8601String(),
);

Play _play(String id, String albumId) => Play(
  id: id,
  albumId: albumId,
  playedAt: _now.toIso8601String(),
  sidePlayed: SidePlayed.full,
  createdAt: _now.toIso8601String(),
);

class _Albums implements IAlbumRepository {
  int findAllCalls = 0;

  @override
  Future<List<Album>> findAll() async {
    findAllCalls++;
    return [_album('a'), _album('b')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plays implements IPlayRepository {
  int findAllCalls = 0;

  @override
  Future<List<Play>> findAll() async {
    findAllCalls++;
    return [_play('p1', 'a'), _play('p2', 'a'), _play('p3', 'b')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Genres implements IGenreRepository {
  int findAllByAlbumCalls = 0;
  int findByAlbumCalls = 0;

  @override
  Future<Map<String, List<Genre>>> findAllByAlbum() async {
    findAllByAlbumCalls++;
    return {
      'a': [Genre(id: 'g1', name: 'Jazz', createdAt: _now.toIso8601String())],
    };
  }

  @override
  Future<List<Genre>> findByAlbum(String albumId) async {
    findByAlbumCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Artists implements IArtistRepository {
  @override
  Future<List<Artist>> findAll() async => [
    Artist(id: 'artist-1', name: 'Artist', createdAt: _now.toIso8601String()),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
