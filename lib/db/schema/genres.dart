import 'package:drift/drift.dart';

/// VinylApp-098.
///
/// Canonical genre rows shared by every album in the collection. Genre names
/// are unique using SQLite's NOCASE collation so common ASCII case variants
/// cannot create duplicate genre rows.
@DataClassName('Genre')
class Genres extends Table {
  TextColumn get id => text()();
  TextColumn get name =>
      text().customConstraint('NOT NULL COLLATE NOCASE UNIQUE')();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
