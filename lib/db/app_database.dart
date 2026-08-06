import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vinyl_app/db/schema/albums.dart';
import 'package:vinyl_app/db/schema/artists.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Albums, Artists])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // Not required by either card's acceptance criteria, but without
        // this, the FK on albums.artistId is decorative only — SQLite
        // silently allows inserts referencing a non-existent artist unless
        // foreign key enforcement is explicitly turned on per-connection.
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
