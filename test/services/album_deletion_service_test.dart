import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/nfc_tag_repository.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/services/album_deletion_service.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test('deletes the album once, then cleans artwork after DB commit', () async {
    final events = <String>[];
    final result = await AlbumDeletionService(
      albumRepository: _Albums(events),
      playRepository: _Plays(events, [_play('play-1'), _play('play-2')]),
      nfcTagRepository: _Nfc(events, linked: true),
      artworkStorageService: _Artwork(events),
    ).deleteAlbum('album-1');

    expect(result.deletedPlayCount, 2);
    expect(result.deletedNfcAssociation, isTrue);
    expect(events, [
      'find-album',
      'find-plays',
      'find-nfc',
      'delete-album',
      'delete-artwork',
    ]);
  });

  test('does not touch artwork if the database deletion fails', () async {
    final events = <String>[];
    final service = AlbumDeletionService(
      albumRepository: _Albums(events, failDelete: true),
      playRepository: _Plays(events, const []),
      nfcTagRepository: _Nfc(events, linked: false),
      artworkStorageService: _Artwork(events),
    );

    await expectLater(
      service.deleteAlbum('album-1'),
      throwsA(isA<StateError>()),
    );
    expect(events, isNot(contains('delete-artwork')));
  });

  test(
    'artwork cleanup failure does not turn a committed delete into failure',
    () async {
      final events = <String>[];
      final result = await AlbumDeletionService(
        albumRepository: _Albums(events),
        playRepository: _Plays(events, const []),
        nfcTagRepository: _Nfc(events, linked: false),
        artworkStorageService: _Artwork(events, failDelete: true),
      ).deleteAlbum('album-1');

      expect(result.deletedPlayCount, 0);
      expect(result.deletedNfcAssociation, isFalse);
      expect(events, contains('delete-album'));
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
  _Albums(this.events, {this.failDelete = false});

  final List<String> events;
  final bool failDelete;

  @override
  Future<Album?> findById(String id) async {
    events.add('find-album');
    return id == _album.id ? _album : null;
  }

  @override
  Future<int> delete(String id) async {
    events.add('delete-album');
    return failDelete ? 0 : 1;
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
  _Plays(this.events, List<Play> plays) : _plays = List.of(plays);

  final List<String> events;
  final List<Play> _plays;

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    events.add('find-plays');
    return List.unmodifiable(_plays);
  }

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

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
  Future<int> delete(String id) => throw UnimplementedError();

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) => throw UnimplementedError();

  @override
  Future<NfcTag> replaceForAlbum({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) => throw UnimplementedError();

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) async => null;
}

class _Artwork extends ArtworkStorageService {
  _Artwork(this.events, {this.failDelete = false});

  final List<String> events;
  final bool failDelete;

  @override
  Future<void> deleteArtwork(String? artworkPath) async {
    events.add('delete-artwork');
    if (failDelete) throw const FileSystemException('cleanup failed');
  }
}
