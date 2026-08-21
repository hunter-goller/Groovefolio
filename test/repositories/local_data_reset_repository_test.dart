import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';
import 'package:vinyl_app/repositories/local_data_reset_repository.dart';
import 'package:vinyl_app/repositories/nfc_tag_repository.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/repositories/track_repository.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
  });

  tearDown(() => db.close());

  test('clearCollectionData removes all collection-owned tables', () async {
    final artistRepository = ArtistRepository(db);
    final albumRepository = AlbumRepository(db);
    final playRepository = PlayRepository(db);
    final nfcRepository = NfcTagRepository(db);
    final genreRepository = GenreRepository(db);
    final trackRepository = TrackRepository(db);
    final releaseLinkRepository = DiscogsReleaseLinkRepository(db);

    final artist = await artistRepository.findOrCreate('John Coltrane');
    final album = await albumRepository.create(
      title: 'Blue Train',
      artistId: artist.id,
      releaseYear: 1957,
    );
    await playRepository.create(
      albumId: album.id,
      playedAt: DateTime.utc(2026, 8, 21),
      sidePlayed: SidePlayed.full,
    );
    await nfcRepository.create(albumId: album.id, nfcTagId: 'tag-1');
    final genre = await genreRepository.findOrCreate('Jazz');
    await genreRepository.setAlbumGenres(album.id, [genre.id]);
    await releaseLinkRepository.link(albumId: album.id, releaseId: 12345);
    await trackRepository.replaceAlbumTracks(album.id, const [
      TrackDraft(title: 'Blue Train', position: 'A1', side: 'A', sequence: 0),
    ]);

    await LocalDataResetRepository(db).clearCollectionData();

    expect(await db.select(db.tracks).get(), isEmpty);
    expect(await db.select(db.albumDiscogsReleases).get(), isEmpty);
    expect(await db.select(db.albumGenres).get(), isEmpty);
    expect(await db.select(db.nfcTags).get(), isEmpty);
    expect(await db.select(db.plays).get(), isEmpty);
    expect(await db.select(db.albums).get(), isEmpty);
    expect(await db.select(db.genres).get(), isEmpty);
    expect(await db.select(db.artists).get(), isEmpty);
  });
}
