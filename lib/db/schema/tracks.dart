import 'package:drift/drift.dart';
import 'package:vinyl_app/db/schema/albums.dart';

/// Persistent album track metadata added by VinylApp-105.
@DataClassName('Track')
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get albumId =>
      text().references(Albums, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();

  /// Original Discogs position when available (for example A1, A2, B1).
  TextColumn get position => text().nullable()();

  /// Vinyl side inferred from [position] when one is available.
  TextColumn get side => text().nullable()();

  /// Stable zero-based release order, independent of display position text.
  IntColumn get sequence => integer()();

  /// Duration in seconds when Discogs provides a parseable duration.
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
