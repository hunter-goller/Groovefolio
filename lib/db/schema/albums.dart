import 'package:drift/drift.dart';
import 'package:vinyl_app/db/schema/artists.dart';

/// VinylApp-009.
@DataClassName('Album')
class Albums extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();

  // Real FK, not a placeholder — Artists exists now, built alongside this.
  TextColumn get artistId => text().references(Artists, #id)();

  IntColumn get releaseYear => integer().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get artworkPath => text().nullable()();
  TextColumn get purchaseDate => text().nullable()();
  IntColumn get purchasePriceCents => integer().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
