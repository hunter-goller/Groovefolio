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
      onCreate: (migrator) async {
        await migrateToV1(migrator);
        await migrateToV2(migrator);
        await migrateToV3(migrator);
        await migrateToV4(migrator);
        await migrateToV5(migrator);
      },
      onUpgrade: (migrator, from, to) async {
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
      },
      beforeOpen: (details) async {
        // SQLite foreign-key enforcement is connection-local and disabled by
        // default. Enable it so all declared relationships are enforced.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
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
