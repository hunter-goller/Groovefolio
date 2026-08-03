import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// The app's single SQLite database connection, managed by Drift.
///
/// TEMPORARY: tables is empty for now — this card (VinylApp-007) is just
/// the connection plumbing. Real tables (albums, artists, plays, nfc_tags)
/// land in the Data Layer epic cards right after this one.
///
/// NOTE: opens the connection manually via LazyDatabase +
/// NativeDatabase.createInBackground instead of the drift_flutter helper
/// package — drift_flutter's newest release requires a newer `drift` core
/// version than we can use here (pinned lower to stay compatible with
/// riverpod_generator's dependency chain). This is drift's own documented
/// manual setup pattern, not a workaround — drift_flutter is optional
/// convenience sugar around exactly this.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  /// Optional executor param lets tests inject an in-memory database
  /// instead of the real file-based one — see app_database_test.dart.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'vinyl_app_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
