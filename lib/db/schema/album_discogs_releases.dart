import 'package:drift/drift.dart';
import 'package:vinyl_app/db/schema/albums.dart';

/// Links a local album to the exact Discogs release selected for it.
@DataClassName('AlbumDiscogsRelease')
class AlbumDiscogsReleases extends Table {
  TextColumn get albumId =>
      text().references(Albums, #id, onDelete: KeyAction.cascade)();
  IntColumn get releaseId => integer().unique()();

  @override
  Set<Column> get primaryKey => {albumId};
}
