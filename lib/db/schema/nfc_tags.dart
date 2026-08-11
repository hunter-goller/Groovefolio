import 'package:drift/drift.dart';
import 'package:vinyl_app/db/schema/albums.dart';

/// VinylApp-040.
///
/// Maps a physical NFC tag identifier to an album. Both [albumId] and
/// [nfcTagId] are unique, enforcing the current product rule that an album has
/// at most one registered NFC tag and a physical tag can belong to only one
/// album.
@DataClassName('NfcTag')
class NfcTags extends Table {
  TextColumn get id => text()();
  TextColumn get albumId => text().unique().references(Albums, #id)();
  TextColumn get nfcTagId => text().unique()();
  TextColumn get writtenAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
