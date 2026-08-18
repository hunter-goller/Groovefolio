import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';

void main() {
  test('links exact Discogs release to a local album', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final artists = ArtistRepository(db);
    final albums = AlbumRepository(db);
    final links = DiscogsReleaseLinkRepository(db);

    final artist = await artists.findOrCreate('John Coltrane');
    final album = await albums.create(title: 'Blue Train', artistId: artist.id);

    await links.link(albumId: album.id, releaseId: 12345);

    expect(await links.findReleaseIdForAlbum(album.id), 12345);
    expect(await links.findAlbumIdForRelease(12345), album.id);
    expect(await links.findAllReleaseIds(), {12345});
  });

  test('Discogs link is removed when its album is deleted', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final artists = ArtistRepository(db);
    final albums = AlbumRepository(db);
    final links = DiscogsReleaseLinkRepository(db);

    final artist = await artists.findOrCreate('Miles Davis');
    final album = await albums.create(
      title: 'Kind of Blue',
      artistId: artist.id,
    );
    await links.link(albumId: album.id, releaseId: 6789);

    await albums.delete(album.id);

    expect(await links.findAlbumIdForRelease(6789), isNull);
  });
}
