import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';
import 'package:vinyl_app/repositories/track_repository.dart';
import 'package:vinyl_app/services/record_write_service.dart';

void main() {
  test(
    'createRecord commits album, release, tracks, and genres together',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final albums = AlbumRepository(db);
      final artists = ArtistRepository(db);
      final genres = GenreRepository(db);
      final tracks = TrackRepository(db);
      final links = DiscogsReleaseLinkRepository(db);
      final service = RecordWriteService(
        transactionRunner: DriftDatabaseTransactionRunner(db),
        albumRepository: albums,
        artistRepository: artists,
        genreRepository: genres,
        trackRepository: tracks,
        releaseLinkRepository: links,
      );

      final album = await service.createRecord(
        title: 'Blue Train',
        artistName: 'John Coltrane',
        releaseYear: 1957,
        label: 'Blue Note',
        discogsReleaseId: 12345,
        genreNames: const ['Jazz', 'Hard Bop'],
        tracks: const [
          TrackDraft(
            title: 'Blue Train',
            sequence: 0,
            position: 'A1',
            side: 'A',
          ),
        ],
      );

      expect((await artists.findById(album.artistId))?.name, 'John Coltrane');
      expect(await links.findReleaseIdForAlbum(album.id), 12345);
      expect((await tracks.findByAlbum(album.id)).single.position, 'A1');
      expect(
        (await genres.findByAlbum(album.id)).map((genre) => genre.name).toSet(),
        {'Jazz', 'Hard Bop'},
      );
    },
  );

  test(
    'createRecord rolls back earlier writes when a later repository fails',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final albums = AlbumRepository(db);
      final artists = ArtistRepository(db);
      final genres = GenreRepository(db);
      final links = DiscogsReleaseLinkRepository(db);
      final service = RecordWriteService(
        transactionRunner: DriftDatabaseTransactionRunner(db),
        albumRepository: albums,
        artistRepository: artists,
        genreRepository: genres,
        trackRepository: _FailingTracks(),
        releaseLinkRepository: links,
      );

      await expectLater(
        service.createRecord(
          title: 'Blue Train',
          artistName: 'John Coltrane',
          discogsReleaseId: 12345,
          tracks: const [TrackDraft(title: 'Blue Train', sequence: 0)],
        ),
        throwsA(isA<StateError>()),
      );

      expect(await albums.findAll(), isEmpty);
      expect(await artists.findAll(), isEmpty);
      expect(await links.findAllReleaseIds(), isEmpty);
    },
  );

  test(
    'updateRecord rolls back album changes when genre assignment fails',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final albums = AlbumRepository(db);
      final artists = ArtistRepository(db);
      final realGenres = GenreRepository(db);
      final tracks = TrackRepository(db);
      final links = DiscogsReleaseLinkRepository(db);
      final artist = await artists.findOrCreate('John Coltrane');
      final existing = await albums.create(
        title: 'Blue Train',
        artistId: artist.id,
        releaseYear: 1957,
      );
      final service = RecordWriteService(
        transactionRunner: DriftDatabaseTransactionRunner(db),
        albumRepository: albums,
        artistRepository: artists,
        genreRepository: _FailingGenreAssignments(realGenres),
        trackRepository: tracks,
        releaseLinkRepository: links,
      );

      await expectLater(
        service.updateRecord(
          existing: existing,
          title: 'Blue Train Deluxe',
          artistName: 'John Coltrane',
          releaseYear: 1957,
          genreNames: const ['Jazz'],
        ),
        throwsA(isA<StateError>()),
      );

      expect((await albums.findById(existing.id))?.title, 'Blue Train');
    },
  );
}

class _FailingTracks implements ITrackRepository {
  @override
  Future<List<Track>> findByAlbum(String albumId) async => const [];

  @override
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  ) {
    throw StateError('track write failed');
  }
}

class _FailingGenreAssignments implements IGenreRepository {
  _FailingGenreAssignments(this.delegate);

  final IGenreRepository delegate;

  @override
  Future<int> delete(String genreId) => delegate.delete(genreId);

  @override
  Future<List<Genre>> findAll() => delegate.findAll();

  @override
  Future<List<Genre>> findByAlbum(String albumId) =>
      delegate.findByAlbum(albumId);

  @override
  Future<Genre?> findById(String id) => delegate.findById(id);

  @override
  Future<Genre?> findByName(String name) => delegate.findByName(name);

  @override
  Future<Genre> findOrCreate(String name) => delegate.findOrCreate(name);

  @override
  Future<int> removeFromAlbum(String albumId, String genreId) =>
      delegate.removeFromAlbum(albumId, genreId);

  @override
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds) {
    throw StateError('genre assignment failed');
  }
}
