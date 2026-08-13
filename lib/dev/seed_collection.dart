import 'package:flutter/foundation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/services/play_logging_service.dart';
import 'package:vinyl_app/types/side_played.dart';

/// Result returned by [seedCollectionForDev].
class DevSeedResult {
  const DevSeedResult({
    required this.createdAlbums,
    required this.reusedAlbums,
    required this.createdPlays,
  });

  final int createdAlbums;
  final int reusedAlbums;
  final int createdPlays;
}

/// Populates the production-on-device database with a small realistic
/// collection for visual development.
///
/// This intentionally uses the real repositories and PlayLoggingService rather
/// than inserting raw Drift companions. It is safe to run repeatedly:
/// existing seeded albums are reused, and plays are only created for seeded
/// albums that do not already have any play history.
Future<DevSeedResult> seedCollectionForDev(AppDatabase db) async {
  if (!kDebugMode) {
    throw StateError('Development seed data may only run in debug builds.');
  }

  final artistRepository = ArtistRepository(db);
  final albumRepository = AlbumRepository(db);
  final playRepository = PlayRepository(db);
  final playLoggingService = PlayLoggingService(
    albumRepository: albumRepository,
    playRepository: playRepository,
  );

  final now = DateTime.now().toUtc();
  var createdAlbums = 0;
  var reusedAlbums = 0;
  var createdPlays = 0;

  final albums = await albumRepository.findAll();
  final knownAlbums = [...albums];

  for (final spec in _seedAlbums) {
    final artist = await artistRepository.findOrCreate(spec.artist);

    Album? album;
    for (final candidate in knownAlbums) {
      if (candidate.artistId == artist.id &&
          candidate.title.toLowerCase() == spec.title.toLowerCase()) {
        album = candidate;
        break;
      }
    }

    if (album == null) {
      album = await albumRepository.create(
        title: spec.title,
        artistId: artist.id,
        releaseYear: spec.releaseYear,
        label: spec.label,
      );
      knownAlbums.add(album);
      createdAlbums++;
    } else {
      reusedAlbums++;
    }

    final existingPlays = await playRepository.findByAlbum(album.id);
    if (existingPlays.isNotEmpty) {
      continue;
    }

    for (var index = 0; index < spec.playAges.length; index++) {
      final side = SidePlayed.values[index % SidePlayed.values.length];
      await playLoggingService.logPlay(
        album.id,
        now.subtract(spec.playAges[index]),
        side,
      );
      createdPlays++;
    }
  }

  return DevSeedResult(
    createdAlbums: createdAlbums,
    reusedAlbums: reusedAlbums,
    createdPlays: createdPlays,
  );
}

class _SeedAlbum {
  const _SeedAlbum({
    required this.artist,
    required this.title,
    required this.releaseYear,
    required this.label,
    required this.playAges,
  });

  final String artist;
  final String title;
  final int releaseYear;
  final String label;
  final List<Duration> playAges;
}

const _seedAlbums = <_SeedAlbum>[
  _SeedAlbum(
    artist: 'Daft Punk',
    title: 'Random Access Memories',
    releaseYear: 2013,
    label: 'Columbia',
    playAges: [
      Duration(hours: 2),
      Duration(days: 5),
      Duration(days: 13),
      Duration(days: 31),
      Duration(days: 74),
    ],
  ),
  _SeedAlbum(
    artist: 'John Coltrane',
    title: 'Blue Train',
    releaseYear: 1957,
    label: 'Blue Note',
    playAges: [Duration(days: 1), Duration(days: 18), Duration(days: 63)],
  ),
  _SeedAlbum(
    artist: 'Tom Petty',
    title: 'Wildflowers',
    releaseYear: 1994,
    label: 'Warner Bros.',
    playAges: [Duration(days: 2)],
  ),
  _SeedAlbum(
    artist: 'Miles Davis',
    title: 'Kind of Blue',
    releaseYear: 1959,
    label: 'Columbia',
    playAges: [
      Duration(days: 4),
      Duration(days: 24),
      Duration(days: 52),
      Duration(days: 108),
    ],
  ),
  _SeedAlbum(
    artist: 'David Bowie',
    title: 'The Rise and Fall of Ziggy Stardust and the Spiders from Mars',
    releaseYear: 1972,
    label: 'RCA',
    playAges: [Duration(days: 9), Duration(days: 88)],
  ),
  _SeedAlbum(
    artist: 'Fleetwood Mac',
    title: 'Rumours',
    releaseYear: 1977,
    label: 'Warner Bros.',
    playAges: [Duration(days: 16)],
  ),
  _SeedAlbum(
    artist: 'Pink Floyd',
    title: 'Wish You Were Here',
    releaseYear: 1975,
    label: 'Harvest',
    playAges: [],
  ),
];
