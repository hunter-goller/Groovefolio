import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vinyl_app/db/migrations/migration_v1.dart';
import 'package:vinyl_app/db/migrations/migration_v2.dart';
import 'package:vinyl_app/db/migrations/migration_v3.dart';
import 'package:vinyl_app/db/migrations/migration_v4.dart';
import 'package:vinyl_app/db/migrations/migration_v5.dart';
import 'package:vinyl_app/db/migrations/migration_v6.dart';
import 'package:vinyl_app/db/migrations/schema_versions.dart';
import 'package:vinyl_app/db/schema/album_discogs_releases.dart';
import 'package:vinyl_app/db/schema/album_genres.dart';
import 'package:vinyl_app/db/schema/albums.dart';
import 'package:vinyl_app/db/schema/artists.dart';
import 'package:vinyl_app/db/schema/genres.dart';
import 'package:vinyl_app/db/schema/nfc_tags.dart';
import 'package:vinyl_app/db/schema/plays.dart';
import 'package:vinyl_app/db/schema/tracks.dart';
import 'package:vinyl_app/types/side_played.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Artists,
    Albums,
    Plays,
    NfcTags,
    Genres,
    AlbumGenres,
    AlbumDiscogsReleases,
    Tracks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => SchemaVersions.current;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // Build every frozen schema version in order so a fresh install follows
      // the same physical schema path as an upgraded database.
      onCreate: (migrator) => _migrateAtomically(migrator, 0, schemaVersion),
      onUpgrade: _migrateAtomically,
      beforeOpen: (details) async {
        // This must run outside the migration transaction: SQLite ignores
        // changes to foreign_keys while a transaction is active.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _migrateAtomically(Migrator migrator, int from, int to) async {
    if (from > to) {
      throw StateError(
        'Database schema $from is newer than supported schema $to.',
      );
    }

    await transaction(() async {
      if (from < SchemaVersions.v1 && to >= SchemaVersions.v1) {
        await migrateToV1(migrator);
      }
      if (from < SchemaVersions.v2 && to >= SchemaVersions.v2) {
        await migrateToV2(migrator);
      }
      if (from < SchemaVersions.v3 && to >= SchemaVersions.v3) {
        await migrateToV3(migrator);
      }
      if (from < SchemaVersions.v4 && to >= SchemaVersions.v4) {
        await migrateToV4(migrator);
      }
      if (from < SchemaVersions.v5 && to >= SchemaVersions.v5) {
        await migrateToV5(migrator);
      }
      if (from < SchemaVersions.v6 && to >= SchemaVersions.v6) {
        await migrateToV6(migrator);
      }
      // NativeDatabase normally writes user_version after all migration and
      // beforeOpen callbacks return. Commit it with the schema instead, so
      // interruption after this transaction cannot cause a completed upgrade
      // to run again. Drift's later write of the same version is harmless.
      // `to` comes from Drift's integer schema version, not external input.
      await customStatement('PRAGMA user_version = $to');
    });
  }

  /// Opens the underlying database and waits for creation/migrations plus
  /// [MigrationStrategy.beforeOpen] to finish.
  Future<void> initialize() async {
    await customSelect('SELECT 1').getSingle();
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'vinyl_app_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
