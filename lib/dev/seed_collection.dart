import 'package:flutter/foundation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/dev/dev_seed_artwork_source.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/services/play_logging_service.dart';
import 'package:vinyl_app/types/side_played.dart';

/// Result returned by development seed operations.
class DevSeedResult {
  const DevSeedResult({
    required this.createdAlbums,
    required this.reusedAlbums,
    required this.createdPlays,
    this.downloadedArtwork = 0,
    this.missingArtwork = 0,
    this.removedAlbums = 0,
  });

  final int createdAlbums;
  final int reusedAlbums;
  final int createdPlays;
  final int downloadedArtwork;
  final int missingArtwork;
  final int removedAlbums;
}

class DevSeedProgress {
  const DevSeedProgress({
    required this.stage,
    required this.completedAlbums,
    required this.totalAlbums,
    this.currentAlbum,
    this.downloadedArtwork = 0,
    this.missingArtwork = 0,
  });

  final String stage;
  final int completedAlbums;
  final int totalAlbums;
  final String? currentAlbum;
  final int downloadedArtwork;
  final int missingArtwork;

  double get fraction => totalAlbums == 0 ? 0 : completedAlbums / totalAlbums;
}

typedef DevSeedProgressCallback = void Function(DevSeedProgress progress);

/// Populates the production-on-device database with a broad realistic
/// collection for visual and Stats development.
///
/// This intentionally uses the real repositories and PlayLoggingService rather
/// than inserting raw Drift companions. It is safe to run repeatedly:
/// existing seeded albums are reused, missing seed genres are added without
/// removing user-added genre mappings, recent relative plays are only created
/// for seeded albums with no history, and fixed historical Stats test plays
/// are backfilled idempotently when missing.
Future<DevSeedResult> seedCollectionForDev(
  AppDatabase db, {
  DevSeedArtworkSource? artworkSource,
  DevSeedProgressCallback? onProgress,
  int albumLimit = 10,
}) async {
  if (!kDebugMode) {
    throw StateError('Development seed data may only run in debug builds.');
  }

  final artistRepository = ArtistRepository(db);
  final albumRepository = AlbumRepository(db);
  final genreRepository = GenreRepository(db);
  final playRepository = PlayRepository(db);
  final playLoggingService = PlayLoggingService(
    albumRepository: albumRepository,
    playRepository: playRepository,
  );

  final now = DateTime.now().toUtc();
  var createdAlbums = 0;
  var reusedAlbums = 0;
  var createdPlays = 0;
  var downloadedArtwork = 0;
  var missingArtwork = 0;

  final albums = await albumRepository.findAll();
  final knownAlbums = [...albums];
  final selectedSeedAlbums = _seedAlbums
      .take(albumLimit <= 0 ? 1 : albumLimit)
      .toList(growable: false);

  for (var specIndex = 0; specIndex < selectedSeedAlbums.length; specIndex++) {
    final spec = selectedSeedAlbums[specIndex];
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

    var seededAlbum = album;

    if (artworkSource != null &&
        (seededAlbum.artworkPath == null ||
            seededAlbum.artworkPath!.trim().isEmpty)) {
      try {
        final artworkPath = await artworkSource.saveArtworkForAlbum(
          artist: spec.artist,
          title: spec.title,
          releaseYear: spec.releaseYear,
          albumId: seededAlbum.id,
        );

        if (artworkPath == null) {
          missingArtwork++;
        } else {
          final albumWithArtwork = Album(
            id: seededAlbum.id,
            title: seededAlbum.title,
            artistId: seededAlbum.artistId,
            releaseYear: seededAlbum.releaseYear,
            label: seededAlbum.label,
            artworkPath: artworkPath,
            purchaseDate: seededAlbum.purchaseDate,
            purchasePriceCents: seededAlbum.purchasePriceCents,
            createdAt: seededAlbum.createdAt,
          );
          final updated = await albumRepository.update(albumWithArtwork);
          if (!updated) {
            await artworkSource.deleteArtwork(artworkPath);
            throw StateError(
              'Could not attach downloaded artwork to ${seededAlbum.title}.',
            );
          }
          seededAlbum = albumWithArtwork;
          downloadedArtwork++;
        }
      } catch (error) {
        // Artwork is development polish, not a reason to leave the reset with
        // a half-built database when a network request fails.
        debugPrint(
          'Dev seed artwork unavailable for ${spec.artist} — ${spec.title}: '
          '$error',
        );
        missingArtwork++;
      }
    }

    await _ensureSeedGenres(
      genreRepository: genreRepository,
      albumId: seededAlbum.id,
      genreNames: spec.genres,
    );

    final existingPlays = await playRepository.findByAlbum(seededAlbum.id);

    if (existingPlays.isEmpty) {
      for (var index = 0; index < spec.playAges.length; index++) {
        final side = SidePlayed.values[index % SidePlayed.values.length];
        await playLoggingService.logPlay(
          seededAlbum.id,
          now.subtract(spec.playAges[index]),
          side,
        );
        createdPlays++;
      }
    }

    final knownPlayedAt = existingPlays.map((play) => play.playedAt).toSet();
    for (var index = 0; index < spec.historicalPlayDates.length; index++) {
      final playedAt = DateTime.parse(spec.historicalPlayDates[index]).toUtc();
      final normalizedPlayedAt = playedAt.toIso8601String();
      if (knownPlayedAt.contains(normalizedPlayedAt)) {
        continue;
      }

      final side = SidePlayed.values[index % SidePlayed.values.length];
      await playLoggingService.logPlay(seededAlbum.id, playedAt, side);
      knownPlayedAt.add(normalizedPlayedAt);
      createdPlays++;
    }

    onProgress?.call(
      DevSeedProgress(
        stage: 'Seeding collection',
        completedAlbums: specIndex + 1,
        totalAlbums: selectedSeedAlbums.length,
        currentAlbum: '${spec.artist} — ${spec.title}',
        downloadedArtwork: downloadedArtwork,
        missingArtwork: missingArtwork,
      ),
    );
  }

  return DevSeedResult(
    createdAlbums: createdAlbums,
    reusedAlbums: reusedAlbums,
    createdPlays: createdPlays,
    downloadedArtwork: downloadedArtwork,
    missingArtwork: missingArtwork,
  );
}

/// Destructively clears the on-device development database and creates a fresh
/// deterministic seed collection. Existing artwork files referenced by Albums
/// are removed before the rows are deleted.
Future<DevSeedResult> resetAndSeedCollectionForDev(
  AppDatabase db, {
  required DevSeedArtworkSource artworkSource,
  DevSeedProgressCallback? onProgress,
  int albumLimit = 10,
}) async {
  if (!kDebugMode) {
    throw StateError('Development seed data may only run in debug builds.');
  }

  final albumRepository = AlbumRepository(db);
  final existingAlbums = await albumRepository.findAll();
  final selectedAlbumCount = _seedAlbums
      .take(albumLimit <= 0 ? 1 : albumLimit)
      .length;

  onProgress?.call(
    DevSeedProgress(
      stage: 'Clearing existing dev data',
      completedAlbums: 0,
      totalAlbums: selectedAlbumCount,
    ),
  );

  for (final album in existingAlbums) {
    await artworkSource.deleteArtwork(album.artworkPath);
  }

  await db.transaction(() async {
    // Delete dependents first because Plays and NfcTags intentionally do not
    // rely on database-level cascading.
    await db.delete(db.albumGenres).go();
    await db.delete(db.plays).go();
    await db.delete(db.nfcTags).go();
    await db.delete(db.albums).go();
    await db.delete(db.genres).go();
    await db.delete(db.artists).go();
  });

  final seeded = await seedCollectionForDev(
    db,
    artworkSource: artworkSource,
    onProgress: onProgress,
    albumLimit: albumLimit,
  );

  return DevSeedResult(
    createdAlbums: seeded.createdAlbums,
    reusedAlbums: seeded.reusedAlbums,
    createdPlays: seeded.createdPlays,
    downloadedArtwork: seeded.downloadedArtwork,
    missingArtwork: seeded.missingArtwork,
    removedAlbums: existingAlbums.length,
  );
}

Future<void> _ensureSeedGenres({
  required GenreRepository genreRepository,
  required String albumId,
  required List<String> genreNames,
}) async {
  final existingGenres = await genreRepository.findByAlbum(albumId);
  final genreIds = existingGenres.map((genre) => genre.id).toSet();

  for (final name in genreNames) {
    final genre = await genreRepository.findOrCreate(name);
    genreIds.add(genre.id);
  }

  await genreRepository.setAlbumGenres(albumId, genreIds);
}

class _SeedAlbum {
  const _SeedAlbum({
    required this.artist,
    required this.title,
    required this.releaseYear,
    required this.label,
    required this.genres,
    required this.playAges,
    this.historicalPlayDates = const [],
  });

  final String artist;
  final String title;
  final int releaseYear;
  final String label;
  final List<String> genres;
  final List<Duration> playAges;

  /// Fixed UTC timestamps used only to exercise historical Stats behavior.
  ///
  /// These are compared against persisted playedAt values before insertion,
  /// so rerunning the dev seed safely backfills missing history without
  /// duplicating it.
  final List<String> historicalPlayDates;
}

const _seedAlbums = <_SeedAlbum>[
  _SeedAlbum(
    artist: 'Taylor Swift',
    title: 'folklore',
    releaseYear: 2020,
    label: 'Republic',
    genres: ['Indie Folk', 'Pop'],
    playAges: [Duration(days: 8), Duration(days: 44)],
    historicalPlayDates: [
      '2025-05-17T20:00:00.000Z',
      '2024-12-14T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Taylor Swift',
    title: 'Lover',
    releaseYear: 2019,
    label: 'Republic',
    genres: ['Pop', 'Synth-Pop'],
    playAges: [Duration(days: 18), Duration(days: 67)],
    historicalPlayDates: [
      '2025-07-18T20:00:00.000Z',
      '2024-02-16T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Taylor Swift',
    title: '1989',
    releaseYear: 2014,
    label: 'Big Machine',
    genres: ['Pop', 'Synth-Pop'],
    playAges: [Duration(days: 9), Duration(days: 33), Duration(days: 88)],
    historicalPlayDates: [
      '2025-10-27T20:00:00.000Z',
      '2024-08-10T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Taylor Swift',
    title: 'Midnights',
    releaseYear: 2022,
    label: 'Republic',
    genres: ['Pop', 'Synth-Pop'],
    playAges: [Duration(days: 5), Duration(days: 26), Duration(days: 73)],
    historicalPlayDates: [
      '2025-12-13T20:00:00.000Z',
      '2024-11-03T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Pink Floyd',
    title: 'Wish You Were Here',
    releaseYear: 1975,
    label: 'Harvest',
    genres: ['Progressive Rock', 'Art Rock'],
    playAges: [],
  ),
  _SeedAlbum(
    artist: 'Joni Mitchell',
    title: 'Blue',
    releaseYear: 1971,
    label: 'Reprise',
    genres: ['Folk', 'Singer-Songwriter'],
    playAges: [Duration(days: 52)],
    historicalPlayDates: [
      '2025-06-21T20:00:00.000Z',
      '2024-01-06T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Nirvana',
    title: 'Nevermind',
    releaseYear: 1991,
    label: 'DGC',
    genres: ['Grunge', 'Alternative Rock'],
    playAges: [Duration(days: 3), Duration(days: 27), Duration(days: 120)],
    historicalPlayDates: [
      '2025-02-08T20:00:00.000Z',
      '2024-08-17T20:00:00.000Z',
      '2023-11-04T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Amy Winehouse',
    title: 'Back to Black',
    releaseYear: 2006,
    label: 'Island',
    genres: ['Soul', 'R&B'],
    playAges: [Duration(days: 22)],
    historicalPlayDates: [
      '2025-11-22T20:00:00.000Z',
      '2024-06-22T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'OutKast',
    title: 'Aquemini',
    releaseYear: 1998,
    label: 'LaFace',
    genres: ['Hip-Hop', 'Southern Hip-Hop'],
    playAges: [Duration(days: 29)],
    historicalPlayDates: [
      '2025-08-09T20:00:00.000Z',
      '2024-01-13T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Stevie Wonder',
    title: 'Songs in the Key of Life',
    releaseYear: 1976,
    label: 'Tamla',
    genres: ['Soul', 'Funk', 'R&B'],
    playAges: [Duration(days: 14), Duration(days: 83)],
    historicalPlayDates: [
      '2025-03-01T20:00:00.000Z',
      '2024-09-21T20:00:00.000Z',
      '2023-04-15T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Johnny Cash',
    title: 'At Folsom Prison',
    releaseYear: 1968,
    label: 'Columbia',
    genres: ['Country', 'Americana'],
    playAges: [Duration(days: 76)],
    historicalPlayDates: [
      '2025-03-22T20:00:00.000Z',
      '2024-09-07T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Bob Dylan',
    title: 'Blood on the Tracks',
    releaseYear: 1975,
    label: 'Columbia',
    genres: ['Folk Rock', 'Singer-Songwriter'],
    playAges: [Duration(days: 62)],
    historicalPlayDates: [
      '2025-10-25T20:00:00.000Z',
      '2024-05-11T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Billie Eilish',
    title: 'When We All Fall Asleep, Where Do We Go?',
    releaseYear: 2019,
    label: 'Darkroom',
    genres: ['Pop', 'Electropop'],
    playAges: [Duration(days: 47)],
    historicalPlayDates: [
      '2025-04-04T20:00:00.000Z',
      '2023-10-21T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Dolly Parton',
    title: 'Jolene',
    releaseYear: 1974,
    label: 'RCA',
    genres: ['Country', 'Country Pop'],
    playAges: [Duration(days: 30)],
    historicalPlayDates: [
      '2025-08-02T20:00:00.000Z',
      '2024-02-10T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Iron Maiden',
    title: 'The Number of the Beast',
    releaseYear: 1982,
    label: 'EMI',
    genres: ['Metal', 'Heavy Metal'],
    playAges: [Duration(days: 28)],
    historicalPlayDates: [
      '2025-08-16T20:00:00.000Z',
      '2024-02-17T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Daft Punk',
    title: 'Random Access Memories',
    releaseYear: 2013,
    label: 'Columbia',
    genres: ['Electronic', 'Disco', 'Funk'],
    playAges: [
      Duration(hours: 2),
      Duration(days: 5),
      Duration(days: 13),
      Duration(days: 31),
      Duration(days: 74),
    ],
    historicalPlayDates: [
      '2025-01-18T20:00:00.000Z',
      '2025-04-12T20:00:00.000Z',
      '2025-11-08T20:00:00.000Z',
      '2024-03-16T20:00:00.000Z',
      '2024-10-05T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'John Coltrane',
    title: 'Blue Train',
    releaseYear: 1957,
    label: 'Blue Note',
    genres: ['Jazz', 'Hard Bop'],
    playAges: [Duration(days: 1), Duration(days: 18), Duration(days: 63)],
    historicalPlayDates: [
      '2025-02-14T20:00:00.000Z',
      '2025-06-21T20:00:00.000Z',
      '2025-09-13T20:00:00.000Z',
      '2024-01-20T20:00:00.000Z',
      '2024-07-27T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Tom Petty',
    title: 'Wildflowers',
    releaseYear: 1994,
    label: 'Warner Bros.',
    genres: ['Rock', 'Heartland Rock'],
    playAges: [Duration(days: 2)],
    historicalPlayDates: [
      '2025-03-22T20:00:00.000Z',
      '2024-09-07T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Miles Davis',
    title: 'Kind of Blue',
    releaseYear: 1959,
    label: 'Columbia',
    genres: ['Jazz', 'Modal Jazz'],
    playAges: [
      Duration(days: 4),
      Duration(days: 24),
      Duration(days: 52),
      Duration(days: 108),
    ],
    historicalPlayDates: [
      '2025-01-04T20:00:00.000Z',
      '2025-05-17T20:00:00.000Z',
      '2025-08-23T20:00:00.000Z',
      '2025-12-06T20:00:00.000Z',
      '2024-02-10T20:00:00.000Z',
      '2024-05-11T20:00:00.000Z',
      '2024-12-14T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'David Bowie',
    title: 'The Rise and Fall of Ziggy Stardust and the Spiders from Mars',
    releaseYear: 1972,
    label: 'RCA',
    genres: ['Glam Rock', 'Rock'],
    playAges: [Duration(days: 9), Duration(days: 88)],
    historicalPlayDates: [
      '2025-04-26T20:00:00.000Z',
      '2025-10-18T20:00:00.000Z',
      '2024-06-22T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Fleetwood Mac',
    title: 'Rumours',
    releaseYear: 1977,
    label: 'Warner Bros.',
    genres: ['Rock', 'Soft Rock'],
    playAges: [Duration(days: 16)],
    historicalPlayDates: [
      '2025-07-12T20:00:00.000Z',
      '2025-11-29T20:00:00.000Z',
      '2024-04-13T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Radiohead',
    title: 'OK Computer',
    releaseYear: 1997,
    label: 'Parlophone',
    genres: ['Alternative Rock', 'Art Rock'],
    playAges: [Duration(days: 6), Duration(days: 48)],
    historicalPlayDates: [
      '2025-03-15T20:00:00.000Z',
      '2025-10-11T20:00:00.000Z',
      '2024-04-06T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'The Beatles',
    title: 'Abbey Road',
    releaseYear: 1969,
    label: 'Apple',
    genres: ['Rock', 'Pop Rock'],
    playAges: [Duration(days: 8), Duration(days: 41), Duration(days: 150)],
    historicalPlayDates: [
      '2025-01-25T20:00:00.000Z',
      '2024-06-29T20:00:00.000Z',
      '2023-09-16T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Led Zeppelin',
    title: 'Led Zeppelin IV',
    releaseYear: 1971,
    label: 'Atlantic',
    genres: ['Rock', 'Hard Rock'],
    playAges: [Duration(days: 12), Duration(days: 77)],
    historicalPlayDates: [
      '2025-05-10T20:00:00.000Z',
      '2024-02-24T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'The Clash',
    title: 'London Calling',
    releaseYear: 1979,
    label: 'CBS',
    genres: ['Punk', 'Post-Punk'],
    playAges: [Duration(days: 15)],
    historicalPlayDates: [
      '2025-07-05T20:00:00.000Z',
      '2024-11-16T20:00:00.000Z',
      '2023-05-20T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Joy Division',
    title: 'Unknown Pleasures',
    releaseYear: 1979,
    label: 'Factory',
    genres: ['Post-Punk', 'Gothic Rock'],
    playAges: [Duration(days: 21)],
    historicalPlayDates: [
      '2025-09-20T20:00:00.000Z',
      '2024-03-09T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'The Cure',
    title: 'Disintegration',
    releaseYear: 1989,
    label: 'Fiction',
    genres: ['Gothic Rock', 'Alternative Rock'],
    playAges: [Duration(days: 11), Duration(days: 65)],
    historicalPlayDates: [
      '2025-02-22T20:00:00.000Z',
      '2024-10-26T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Talking Heads',
    title: 'Remain in Light',
    releaseYear: 1980,
    label: 'Sire',
    genres: ['New Wave', 'Art Rock', 'Funk'],
    playAges: [Duration(days: 7), Duration(days: 39)],
    historicalPlayDates: [
      '2025-04-19T20:00:00.000Z',
      '2024-07-13T20:00:00.000Z',
      '2023-12-02T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Prince',
    title: 'Purple Rain',
    releaseYear: 1984,
    label: 'Warner Bros.',
    genres: ['Pop', 'Funk', 'Rock'],
    playAges: [Duration(days: 5), Duration(days: 33), Duration(days: 92)],
    historicalPlayDates: [
      '2025-06-14T20:00:00.000Z',
      '2024-01-27T20:00:00.000Z',
      '2023-08-12T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Michael Jackson',
    title: 'Thriller',
    releaseYear: 1982,
    label: 'Epic',
    genres: ['Pop', 'R&B', 'Funk'],
    playAges: [Duration(days: 10), Duration(days: 56)],
    historicalPlayDates: [
      '2025-08-30T20:00:00.000Z',
      '2024-05-18T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Marvin Gaye',
    title: 'What\'s Going On',
    releaseYear: 1971,
    label: 'Tamla',
    genres: ['Soul', 'R&B'],
    playAges: [Duration(days: 17), Duration(days: 98)],
    historicalPlayDates: [
      '2025-01-11T20:00:00.000Z',
      '2024-12-07T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Aretha Franklin',
    title: 'I Never Loved a Man the Way I Love You',
    releaseYear: 1967,
    label: 'Atlantic',
    genres: ['Soul', 'R&B'],
    playAges: [Duration(days: 32)],
    historicalPlayDates: [
      '2025-05-24T20:00:00.000Z',
      '2024-08-03T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Al Green',
    title: 'Let\'s Stay Together',
    releaseYear: 1972,
    label: 'Hi',
    genres: ['Soul', 'R&B'],
    playAges: [Duration(days: 45)],
    historicalPlayDates: [
      '2025-11-15T20:00:00.000Z',
      '2023-07-22T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Parliament',
    title: 'Mothership Connection',
    releaseYear: 1975,
    label: 'Casablanca',
    genres: ['Funk', 'P-Funk'],
    playAges: [Duration(days: 19), Duration(days: 70)],
    historicalPlayDates: [
      '2025-02-01T20:00:00.000Z',
      '2024-06-08T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Funkadelic',
    title: 'Maggot Brain',
    releaseYear: 1971,
    label: 'Westbound',
    genres: ['Funk', 'Psychedelic Rock'],
    playAges: [Duration(days: 26)],
    historicalPlayDates: [
      '2025-09-06T20:00:00.000Z',
      '2024-03-30T20:00:00.000Z',
      '2023-10-14T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'A Tribe Called Quest',
    title: 'The Low End Theory',
    releaseYear: 1991,
    label: 'Jive',
    genres: ['Hip-Hop', 'Jazz Rap'],
    playAges: [Duration(days: 4), Duration(days: 22), Duration(days: 61)],
    historicalPlayDates: [
      '2025-04-05T20:00:00.000Z',
      '2024-07-20T20:00:00.000Z',
      '2023-01-28T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Nas',
    title: 'Illmatic',
    releaseYear: 1994,
    label: 'Columbia',
    genres: ['Hip-Hop', 'East Coast Hip-Hop'],
    playAges: [Duration(days: 9), Duration(days: 54)],
    historicalPlayDates: [
      '2025-06-28T20:00:00.000Z',
      '2024-02-03T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Wu-Tang Clan',
    title: 'Enter the Wu-Tang (36 Chambers)',
    releaseYear: 1993,
    label: 'Loud',
    genres: ['Hip-Hop', 'East Coast Hip-Hop'],
    playAges: [Duration(days: 13), Duration(days: 110)],
    historicalPlayDates: [
      '2025-10-04T20:00:00.000Z',
      '2024-11-02T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Kendrick Lamar',
    title: 'To Pimp a Butterfly',
    releaseYear: 2015,
    label: 'Top Dawg',
    genres: ['Hip-Hop', 'Jazz Rap', 'Funk'],
    playAges: [Duration(days: 1), Duration(days: 18), Duration(days: 36)],
    historicalPlayDates: [
      '2025-03-29T20:00:00.000Z',
      '2024-05-04T20:00:00.000Z',
      '2023-06-17T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Lauryn Hill',
    title: 'The Miseducation of Lauryn Hill',
    releaseYear: 1998,
    label: 'Ruffhouse',
    genres: ['Hip-Hop', 'R&B', 'Soul'],
    playAges: [Duration(days: 24), Duration(days: 81)],
    historicalPlayDates: [
      '2025-12-13T20:00:00.000Z',
      '2024-09-14T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Massive Attack',
    title: 'Mezzanine',
    releaseYear: 1998,
    label: 'Virgin',
    genres: ['Trip-Hop', 'Electronic'],
    playAges: [Duration(days: 16), Duration(days: 46)],
    historicalPlayDates: [
      '2025-02-15T20:00:00.000Z',
      '2024-04-27T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Portishead',
    title: 'Dummy',
    releaseYear: 1994,
    label: 'Go! Beat',
    genres: ['Trip-Hop', 'Electronic'],
    playAges: [Duration(days: 20)],
    historicalPlayDates: [
      '2025-07-19T20:00:00.000Z',
      '2023-11-25T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Aphex Twin',
    title: 'Selected Ambient Works 85-92',
    releaseYear: 1992,
    label: 'Apollo',
    genres: ['Electronic', 'Ambient', 'Techno'],
    playAges: [Duration(days: 37)],
    historicalPlayDates: [
      '2025-01-31T20:00:00.000Z',
      '2024-06-15T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Boards of Canada',
    title: 'Music Has the Right to Children',
    releaseYear: 1998,
    label: 'Warp',
    genres: ['Electronic', 'IDM', 'Ambient'],
    playAges: [],
    historicalPlayDates: [
      '2025-05-03T20:00:00.000Z',
      '2024-10-12T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Kraftwerk',
    title: 'Trans-Europe Express',
    releaseYear: 1977,
    label: 'Kling Klang',
    genres: ['Electronic', 'Krautrock'],
    playAges: [Duration(days: 68)],
    historicalPlayDates: [
      '2024-03-23T20:00:00.000Z',
      '2023-09-09T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Depeche Mode',
    title: 'Violator',
    releaseYear: 1990,
    label: 'Mute',
    genres: ['Synth-Pop', 'Alternative'],
    playAges: [Duration(days: 23), Duration(days: 75)],
    historicalPlayDates: [
      '2025-06-07T20:00:00.000Z',
      '2024-12-21T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'New Order',
    title: 'Power, Corruption & Lies',
    releaseYear: 1983,
    label: 'Factory',
    genres: ['New Wave', 'Post-Punk', 'Synth-Pop'],
    playAges: [Duration(days: 31)],
    historicalPlayDates: [
      '2025-04-12T20:00:00.000Z',
      '2024-08-24T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Metallica',
    title: 'Master of Puppets',
    releaseYear: 1986,
    label: 'Elektra',
    genres: ['Metal', 'Thrash Metal'],
    playAges: [Duration(days: 2), Duration(days: 35), Duration(days: 102)],
    historicalPlayDates: [
      '2025-01-17T20:00:00.000Z',
      '2024-05-25T20:00:00.000Z',
      '2023-12-30T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Black Sabbath',
    title: 'Paranoid',
    releaseYear: 1970,
    label: 'Vertigo',
    genres: ['Metal', 'Heavy Metal'],
    playAges: [Duration(days: 18), Duration(days: 90)],
    historicalPlayDates: [
      '2025-03-08T20:00:00.000Z',
      '2024-07-06T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Slayer',
    title: 'Reign in Blood',
    releaseYear: 1986,
    label: 'Def Jam',
    genres: ['Metal', 'Thrash Metal'],
    playAges: [],
    historicalPlayDates: [
      '2024-10-19T20:00:00.000Z',
      '2023-06-03T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Tool',
    title: 'Lateralus',
    releaseYear: 2001,
    label: 'Volcano',
    genres: ['Progressive Metal', 'Alternative Metal'],
    playAges: [Duration(days: 43)],
    historicalPlayDates: [
      '2025-11-01T20:00:00.000Z',
      '2024-04-20T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Queens of the Stone Age',
    title: 'Songs for the Deaf',
    releaseYear: 2002,
    label: 'Interscope',
    genres: ['Alternative Rock', 'Stoner Rock'],
    playAges: [Duration(days: 6), Duration(days: 58)],
    historicalPlayDates: [
      '2025-05-31T20:00:00.000Z',
      '2024-09-28T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'The Strokes',
    title: 'Is This It',
    releaseYear: 2001,
    label: 'RCA',
    genres: ['Indie Rock', 'Garage Rock'],
    playAges: [Duration(days: 14), Duration(days: 49)],
    historicalPlayDates: [
      '2025-02-28T20:00:00.000Z',
      '2024-12-28T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Arctic Monkeys',
    title: 'Whatever People Say I Am, That\'s What I\'m Not',
    releaseYear: 2006,
    label: 'Domino',
    genres: ['Indie Rock', 'Garage Rock'],
    playAges: [Duration(days: 34)],
    historicalPlayDates: [
      '2025-07-26T20:00:00.000Z',
      '2024-03-02T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Tame Impala',
    title: 'Currents',
    releaseYear: 2015,
    label: 'Modular',
    genres: ['Psychedelic Pop', 'Indie'],
    playAges: [Duration(days: 5), Duration(days: 67)],
    historicalPlayDates: [
      '2025-09-27T20:00:00.000Z',
      '2024-06-01T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Phoebe Bridgers',
    title: 'Punisher',
    releaseYear: 2020,
    label: 'Dead Oceans',
    genres: ['Indie Rock', 'Indie Folk'],
    playAges: [Duration(days: 25)],
    historicalPlayDates: [
      '2025-04-26T20:00:00.000Z',
      '2024-11-23T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Bon Iver',
    title: 'For Emma, Forever Ago',
    releaseYear: 2007,
    label: 'Jagjaguwar',
    genres: ['Indie Folk', 'Folk'],
    playAges: [Duration(days: 40)],
    historicalPlayDates: [
      '2025-01-04T20:00:00.000Z',
      '2023-08-26T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Neil Young',
    title: 'Harvest',
    releaseYear: 1972,
    label: 'Reprise',
    genres: ['Folk Rock', 'Country Rock'],
    playAges: [],
    historicalPlayDates: [
      '2024-07-27T20:00:00.000Z',
      '2023-03-18T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Lorde',
    title: 'Melodrama',
    releaseYear: 2017,
    label: 'Republic',
    genres: ['Pop', 'Electropop'],
    playAges: [Duration(days: 27)],
    historicalPlayDates: [
      '2025-09-13T20:00:00.000Z',
      '2024-04-13T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'Beyoncé',
    title: 'Renaissance',
    releaseYear: 2022,
    label: 'Parkwood',
    genres: ['Pop', 'Dance', 'R&B'],
    playAges: [Duration(days: 3), Duration(days: 38)],
    historicalPlayDates: [
      '2025-02-14T20:00:00.000Z',
      '2024-08-10T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'SZA',
    title: 'SOS',
    releaseYear: 2022,
    label: 'Top Dawg',
    genres: ['R&B', 'Alternative R&B'],
    playAges: [Duration(days: 12), Duration(days: 59)],
    historicalPlayDates: [
      '2025-06-13T20:00:00.000Z',
      '2024-01-20T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'The Smashing Pumpkins',
    title: 'Siamese Dream',
    releaseYear: 1993,
    label: 'Virgin',
    genres: ['Alternative Rock', 'Shoegaze'],
    playAges: [Duration(days: 17), Duration(days: 73)],
    historicalPlayDates: [
      '2025-07-11T20:00:00.000Z',
      '2024-03-15T20:00:00.000Z',
    ],
  ),
  _SeedAlbum(
    artist: 'R.E.M.',
    title: 'Automatic for the People',
    releaseYear: 1992,
    label: 'Warner Bros.',
    genres: ['Alternative Rock', 'College Rock'],
    playAges: [Duration(days: 55)],
    historicalPlayDates: [
      '2025-01-10T20:00:00.000Z',
      '2024-11-08T20:00:00.000Z',
    ],
  ),
];
