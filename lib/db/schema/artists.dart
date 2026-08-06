import 'package:drift/drift.dart';

/// VinylApp-010. Deliberately built alongside VinylApp-009 (albums)
/// since albums.artistId has a real foreign key reference to this table.
@DataClassName('Artist')
class Artists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
