import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/migrations/schema_versions.dart';

void main() {
  test('empty database migrates to v1 and creates every v1 table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Opening the database triggers AppDatabase.migration.onCreate.
    // Query sqlite_master so the test verifies the physical schema rather
    // than only exercising generated Drift accessors.
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();

    final tableNames = rows.map((row) => row.read<String>('name')).toSet();

    expect(tableNames, containsAll(<String>{'artists', 'albums', 'plays'}));

    // Also prove that each generated table accessor can query the new schema.
    expect(await db.select(db.artists).get(), isEmpty);
    expect(await db.select(db.albums).get(), isEmpty);
    expect(await db.select(db.plays).get(), isEmpty);

    // Drift should persist the schema version on a newly-created database.
    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), SchemaVersions.v1);
  });
}
