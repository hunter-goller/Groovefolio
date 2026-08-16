import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/nfc_tag_repository.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/services/album_deletion_service.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test('deletes plays and NFC before deleting the album', () async {
    final events = <String>[];
    final albumRepository = _Albums(events);
    final playRepository = _Plays(events, [_play('play-1'), _play('play-2')]);
    final nfcRepository = _Nfc(events, linked: true);

    final result = await AlbumDeletionService(
      albumRepository: albumRepository,
      playRepository: playRepository,
      nfcTagRepository: nfcRepository,
      artworkStorageService: _Artwork(events),
    ).deleteAlbum('album-1');

    expect(result.deletedPlayCount, 2);
    expect(result.deletedNfcAssociation, isTrue);
    expect(events, [
      'find-album',
      'find-plays',
      'delete-play-play-1',
      'delete-play-play-2',
      'find-nfc',
      'delete-nfc',
      'delete-artwork',
      'delete-album',
    ]);
  });

  test('deletes album cleanly when there are no plays or NFC tag', () async {
    final events = <String>[];
    final result = await AlbumDeletionService(
      albumRepository: _Albums(events),
      playRepository: _Plays(events, const []),
      nfcTagRepository: _Nfc(events, linked: false),
      artworkStorageService: _Artwork(events),
    ).deleteAlbum('album-1');

    expect(result.deletedPlayCount, 0);
    expect(result.deletedNfcAssociation, isFalse);
    expect(events.last, 'delete-album');
  });

  test(
    'does not attempt album deletion after an association delete fails',
    () async {
      final events = <String>[];
      final service = AlbumDeletionService(
        albumRepository: _Albums(events),
        playRepository: _Plays(events, [_play('play-1')], failDelete: true),
        nfcTagRepository: _Nfc(events, linked: true),
        artworkStorageService: _Artwork(events),
      );

      await expectLater(
        service.deleteAlbum('album-1'),
        throwsA(isA<StateError>()),
      );

      expect(events, isNot(contains('delete-album')));
      expect(events, isNot(contains('delete-nfc')));
    },
  );

  test('rejects an empty album id before touching repositories', () async {
    final events = <String>[];
    final service = AlbumDeletionService(
      albumRepository: _Albums(events),
      playRepository: _Plays(events, const []),
      nfcTagRepository: _Nfc(events, linked: false),
      artworkStorageService: _Artwork(events),
    );

    await expectLater(service.deleteAlbum('  '), throwsArgumentError);
    expect(events, isEmpty);
  });
}

Album get _album => const Album(
  id: 'album-1',
  title: 'Blue Train',
  artistId: 'artist-1',
  artworkPath: '/fake/artwork/album-1.jpg',
  createdAt: '2026-01-01T00:00:00.000Z',
);

Play _play(String id) => Play(
  id: id,
  albumId: 'album-1',
  playedAt: '2026-08-16T12:00:00.000Z',
  sidePlayed: SidePlayed.full,
  createdAt: '2026-08-16T12:00:00.000Z',
);

class _Albums implements IAlbumRepository {
  _Albums(this.events);
  final List<String> events;

  @override
  Future<Album?> findById(String id) async {
    events.add('find-album');
    return id == _album.id ? _album : null;
  }

  @override
  Future<int> delete(String id) async {
    events.add('delete-album');
    return 1;
  }

  @override
  Future<List<Album>> findAll() async => [_album];

  @override
  Future<List<Album>> search(String query) async => [_album];

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
  Future<bool> update(Album album) => throw UnimplementedError();
}

class _Plays implements IPlayRepository {
  _Plays(this.events, List<Play> plays, {this.failDelete = false})
    : _plays = List.of(plays);

  final List<String> events;
  final List<Play> _plays;
  final bool failDelete;

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    events.add('find-plays');
    return List.unmodifiable(_plays);
  }

  @override
  Future<int> deleteById(String id) async {
    events.add('delete-play-$id');
    if (failDelete) return 0;
    _plays.removeWhere((play) => play.id == id);
    return 1;
  }

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(_plays);

  @override
  Future<int> getPlayCountByAlbum(String albumId) async => _plays.length;

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();
}

class _Nfc implements INfcTagRepository {
  _Nfc(this.events, {required this.linked});

  final List<String> events;
  final bool linked;

  @override
  Future<NfcTag?> findByAlbum(String albumId) async {
    events.add('find-nfc');
    if (!linked) return null;
    return const NfcTag(
      id: 'nfc-1',
      albumId: 'album-1',
      nfcTagId: 'tag-1',
      writtenAt: '2026-08-16T12:00:00.000Z',
    );
  }

  @override
  Future<int> delete(String id) async {
    events.add('delete-nfc');
    return 1;
  }

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) => throw UnimplementedError();

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) async => null;
}

class _Artwork extends ArtworkStorageService {
  _Artwork(this.events);

  final List<String> events;

  @override
  Future<void> deleteArtwork(String? artworkPath) async {
    events.add('delete-artwork');
  }
}
