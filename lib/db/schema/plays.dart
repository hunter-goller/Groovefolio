import 'package:drift/drift.dart';
import 'package:vinyl_app/db/schema/albums.dart';
import 'package:vinyl_app/types/side_played.dart';

/// Converts SidePlayed <-> its enum name string for storage as plain
/// text, per the card's "text enum" column spec. Using a manual
/// TypeConverter (rather than Drift's newer textEnum()/EnumNameConverter
/// convenience helpers) since this is guaranteed stable across Drift
/// versions — this project has already hit several version-specific
/// API availability surprises with the pinned Drift/Riverpod versions.
class SidePlayedConverter extends TypeConverter<SidePlayed, String> {
  const SidePlayedConverter();

  @override
  SidePlayed fromSql(String fromDb) => SidePlayed.values.byName(fromDb);

  @override
  String toSql(SidePlayed value) => value.name;
}

/// VinylApp-011.
@DataClassName('Play')
class Plays extends Table {
  TextColumn get id => text()();
  TextColumn get albumId => text().references(Albums, #id)();
  TextColumn get playedAt => text()();
  TextColumn get sidePlayed => text().map(const SidePlayedConverter())();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
