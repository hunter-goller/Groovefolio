import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/play_logging_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  const album = Album(
    id: 'album-1',
    title: 'Kind of Blue',
    artistId: 'artist-1',
    createdAt: '2026-08-11T00:00:00.000Z',
  );

  group('PlayLoggingService', () {
    test(
      'logPlay creates exactly one play with the requested values',
      () async {
        final albumRepository = _FakeAlbumRepository([album]);
        final playRepository = _FakePlayRepository();
        final service = PlayLoggingService(
          albumRepository: albumRepository,
          playRepository: playRepository,
        );
        final playedAt = DateTime.parse('2026-08-11T18:30:00-04:00');

        final created = await service.logPlay(
          ' album-1 ',
          playedAt,
          SidePlayed.sideA,
        );

        expect(playRepository.createCalls, 1);
        expect(playRepository.plays, hasLength(1));
        expect(created.albumId, album.id);
        expect(created.playedAt, playedAt.toUtc().toIso8601String());
        expect(created.sidePlayed, SidePlayed.sideA);
      },
    );

    test(
      'provider-backed logPlay increments the play repository count',
      () async {
        final albumRepository = _FakeAlbumRepository([album]);
        final playRepository = _FakePlayRepository();
        final container = ProviderContainer(
          overrides: [
            albumRepositoryProvider.overrideWithValue(albumRepository),
            playRepositoryProvider.overrideWithValue(playRepository),
          ],
        );
        addTearDown(container.dispose);

        expect(
          await container
              .read(playRepositoryProvider)
              .getPlayCountByAlbum(album.id),
          0,
        );

        await container
            .read(playLoggingServiceProvider)
            .logPlay(
              album.id,
              DateTime.parse('2026-08-11T22:30:00.000Z'),
              SidePlayed.full,
            );

        expect(
          await container
              .read(playRepositoryProvider)
              .getPlayCountByAlbum(album.id),
          1,
        );
        expect(playRepository.createCalls, 1);
      },
    );

    test('missing album does not create a play', () async {
      final playRepository = _FakePlayRepository();
      final service = PlayLoggingService(
        albumRepository: _FakeAlbumRepository(const []),
        playRepository: playRepository,
      );

      await expectLater(
        service.logPlay(
          'missing-album',
          DateTime.parse('2026-08-11T22:30:00.000Z'),
          SidePlayed.full,
        ),
        throwsA(isA<StateError>()),
      );

      expect(playRepository.createCalls, 0);
      expect(playRepository.plays, isEmpty);
    });

    test('blank album id is rejected before repository access', () async {
      final albumRepository = _FakeAlbumRepository([album]);
      final playRepository = _FakePlayRepository();
      final service = PlayLoggingService(
        albumRepository: albumRepository,
        playRepository: playRepository,
      );

      await expectLater(
        service.logPlay('   ', DateTime.now(), SidePlayed.full),
        throwsArgumentError,
      );

      expect(albumRepository.findByIdCalls, 0);
      expect(playRepository.createCalls, 0);
    });
  });
}

class _FakeAlbumRepository implements IAlbumRepository {
  _FakeAlbumRepository(Iterable<Album> albums)
    : _albums = {for (final album in albums) album.id: album};

  final Map<String, Album> _albums;
  int findByIdCalls = 0;

  @override
  Future<Album?> findById(String id) async {
    findByIdCalls += 1;
    return _albums[id];
  }

  @override
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) => throw UnimplementedError();

  @override
  Future<int> delete(String id) => throw UnimplementedError();

  @override
  Future<List<Album>> findAll() => throw UnimplementedError();

  @override
  Future<List<Album>> search(String query) => throw UnimplementedError();

  @override
  Future<bool> update(Album album) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
  final List<Play> plays = [];
  int createCalls = 0;

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) async {
    createCalls += 1;
    final play = Play(
      id: 'fake-play-$createCalls',
      albumId: albumId,
      playedAt: playedAt.toUtc().toIso8601String(),
      sidePlayed: sidePlayed,
      createdAt: '2026-08-11T22:30:00.000Z',
    );
    plays.add(play);
    return play;
  }

  @override
  Future<int> getPlayCountByAlbum(String albumId) async {
    return plays.where((play) => play.albumId == albumId).length;
  }

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(plays);

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    return plays.where((play) => play.albumId == albumId).toList();
  }

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) =>
      throw UnimplementedError();
}
