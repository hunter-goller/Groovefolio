import 'package:drift/drift.dart';
import 'package:vinyl_app/db/schema/albums.dart';
import 'package:vinyl_app/db/schema/genres.dart';

/// VinylApp-098.
///
/// Many-to-many relationship between albums and genres. The composite primary
/// key prevents the same genre from being assigned to an album more than once.
@DataClassName('AlbumGenre')
class AlbumGenres extends Table {
  TextColumn get albumId =>
      text().references(Albums, #id, onDelete: KeyAction.cascade)();

  TextColumn get genreId =>
      text().references(Genres, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {albumId, genreId};
}
