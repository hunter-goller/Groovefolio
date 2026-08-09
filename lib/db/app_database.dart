import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vinyl_app/db/migrations/migration_v1.dart';
import 'package:vinyl_app/db/migrations/schema_versions.dart';
import 'package:vinyl_app/db/schema/albums.dart';
import 'package:vinyl_app/db/schema/artists.dart';
import 'package:vinyl_app/db/schema/plays.dart';
import 'package:vinyl_app/types/side_played.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Albums, Artists, Plays])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => SchemaVersions.current;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: migrateToV1,
      beforeOpen: (details) async {
        // SQLite foreign-key enforcement is connection-local and disabled by
        // default. Enable it so albums.artistId and plays.albumId are real
        // constraints at runtime.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'vinyl_app_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
