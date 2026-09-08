import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/migrations/migration_v1.dart';
import 'package:vinyl_app/db/migrations/migration_v2.dart';
import 'package:vinyl_app/db/migrations/migration_v3.dart';
import 'package:vinyl_app/db/migrations/migration_v4.dart';
import 'package:vinyl_app/db/migrations/migration_v5.dart';
import 'package:vinyl_app/db/migrations/schema_versions.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('groovefolio-migration-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  for (var version = 0; version < SchemaVersions.current; version++) {
    test(
      'v$version rolls back after every migration statement and retries',
      () async {
        final baseline = File('${directory.path}/baseline.sqlite');
        await _seedHistoricalDatabase(baseline, version);
        final original = await _snapshot(baseline);

        // Discover every write in the real migration runner, including its
        // version write. Fixtures use only the frozen historical definitions.
        final probeFile = await baseline.copy('${directory.path}/probe.sqlite');
        final statements = <String>[];
        final probe = _ObservedDatabase(
          NativeDatabase(probeFile),
          afterWrite: statements.add,
        );
        try {
          await probe.initialize();
        } finally {
          await probe.close();
        }
        expect(statements, isNotEmpty);
        final upgraded = await _snapshot(probeFile);

        for (var stopAfter = 1; stopAfter <= statements.length; stopAfter++) {
          final file = await baseline.copy(
            '${directory.path}/failure-$stopAfter.sqlite',
          );
          var completed = 0;
          final failing = _ObservedDatabase(
            NativeDatabase(file),
            afterWrite: (_) {
              if (++completed == stopAfter) throw const _InjectedFailure();
            },
          );
          try {
            await expectLater(
              failing.initialize(),
              throwsA(isA<_InjectedFailure>()),
              reason:
                  'after statement $stopAfter: ${statements[stopAfter - 1]}',
            );
            expect(completed, stopAfter);
          } finally {
            await failing.close();
          }

          // Read through a separate connection with migrations disabled. Opening
          // AppDatabase normally here could hide a partially persisted upgrade.
          expect(
            await _snapshot(file),
            original,
            reason: 'v$version must be unchanged after statement $stopAfter',
          );

          final retry = AppDatabase(NativeDatabase(file));
          try {
            await retry.initialize();
            final foreignKeys = await retry
                .customSelect('PRAGMA foreign_keys')
                .getSingle();
            expect(foreignKeys.read<int>('foreign_keys'), 1);
            expect(
              await retry.customSelect('PRAGMA foreign_key_check').get(),
              isEmpty,
            );
          } finally {
            await retry.close();
          }
          expect(await _snapshot(file), upgraded);
        }
      },
    );
  }

  for (final version in [0, SchemaVersions.v5]) {
    test(
      'v$version keeps schema and version after post-commit open failure',
      () async {
        final file = File('${directory.path}/post-commit.sqlite');
        await _seedHistoricalDatabase(file, version);
        final failing = _FailAfterMigrationDatabase(NativeDatabase(file));
        try {
          await expectLater(
            failing.initialize(),
            throwsA(isA<_InjectedFailure>()),
          );
        } finally {
          await failing.close();
        }

        // beforeOpen failed before Drift's normal version write. The migration
        // transaction must already have persisted both the schema and version.
        final committed = await _snapshot(file);
        expect(committed['version'], SchemaVersions.current);
        final writes = <String>[];
        final reopened = _ObservedDatabase(
          NativeDatabase(file),
          afterWrite: writes.add,
        );
        try {
          await reopened.initialize();
        } finally {
          await reopened.close();
        }
        expect(
          writes,
          isEmpty,
          reason: 'the committed migration must not rerun',
        );
        expect(await _snapshot(file), committed);
      },
    );
  }

  test(
    'rejects a newer database without downgrading its version or data',
    () async {
      final file = File('${directory.path}/newer.sqlite');
      await _seedHistoricalDatabase(file, SchemaVersions.v5);
      final raw = AppDatabase(NativeDatabase(file, enableMigrations: false));
      try {
        await raw.customStatement(
          'PRAGMA user_version = ${SchemaVersions.current + 1}',
        );
      } finally {
        await raw.close();
      }
      final original = await _snapshot(file);
      final olderApp = AppDatabase(NativeDatabase(file));
      try {
        await expectLater(olderApp.initialize(), throwsA(isA<StateError>()));
      } finally {
        await olderApp.close();
      }
      expect(await _snapshot(file), original);
    },
  );

  test(
    'background connection upgrades and reopens a persisted v5 collection',
    () async {
      final file = File('${directory.path}/background.sqlite');
      await _seedHistoricalDatabase(file, SchemaVersions.v5);
      final original = await _snapshot(file);
      final db = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        await db.initialize();
        expect((await db.select(db.plays).get()).single.id, 'play-1');
        expect((await db.select(db.nfcTags).get()).single.nfcTagId, 'tag-1');
        final foreignKeys = await db
            .customSelect('PRAGMA foreign_keys')
            .getSingle();
        expect(foreignKeys.read<int>('foreign_keys'), 1);
      } finally {
        await db.close();
      }

      final upgraded = await _snapshot(file);
      expect(upgraded['version'], SchemaVersions.current);
      expect(upgraded['data'], original['data']);
      final reopened = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        await reopened.initialize();
        expect(
          (await reopened.select(reopened.tracks).get()).single.id,
          'track-1',
        );
      } finally {
        await reopened.close();
      }
      expect(await _snapshot(file), upgraded);
    },
  );
}

class _InjectedFailure implements Exception {
  const _InjectedFailure();
}

/// Inject faults after real SQLite writes, without production test hooks.
class _ObservedDatabase extends AppDatabase {
  _ObservedDatabase(super.executor, {required this.afterWrite});

  final void Function(String statement) afterWrite;

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    await super.customStatement(statement, args);
    final normalized = statement.trim();
    if (normalized.startsWith('CREATE ') ||
        normalized.startsWith('ALTER ') ||
        normalized.startsWith('INSERT ') ||
        normalized.startsWith('DROP ') ||
        normalized.startsWith('PRAGMA user_version =')) {
      afterWrite(normalized);
    }
  }
}

class _FailAfterMigrationDatabase extends AppDatabase {
  _FailAfterMigrationDatabase(super.executor);

  @override
  MigrationStrategy get migration {
    final original = super.migration;
    return MigrationStrategy(
      onCreate: original.onCreate,
      onUpgrade: original.onUpgrade,
      beforeOpen: (_) async => throw const _InjectedFailure(),
    );
  }
}

/// Creates fixtures using frozen SQL, independently of the current runner.
class _HistoricalDatabase extends AppDatabase {
  _HistoricalDatabase(super.executor, this.version);

  final int version;

  @override
  int get schemaVersion => version;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      final migrations = [
        migrateToV1,
        migrateToV2,
        migrateToV3,
        migrateToV4,
        migrateToV5,
      ];
      for (final migrate in migrations.take(version)) {
        await migrate(migrator);
      }
    },
  );
}

Future<void> _seedHistoricalDatabase(File file, int version) async {
  if (version == 0) {
    await file.create();
    return;
  }
  final db = _HistoricalDatabase(NativeDatabase(file), version);
  try {
    await db.initialize();
    await db.customStatement(
      "INSERT INTO artists VALUES ('artist-1', 'Miles Davis', '2026-08-01T00:00:00.000Z')",
    );
    await db.customStatement(
      'INSERT INTO albums (id, title, artist_id, created_at) VALUES '
      "('album-1', 'Kind of Blue', 'artist-1', '2026-08-01T00:00:00.000Z')",
    );
    await db.customStatement(
      "INSERT INTO plays VALUES ('play-1', 'album-1', "
      "'2026-08-02T20:00:00.000Z', 'full', '2026-08-02T20:00:00.000Z')",
    );
    if (version >= SchemaVersions.v2) {
      await db.customStatement(
        "INSERT INTO nfc_tags VALUES ('nfc-1', 'album-1', 'tag-1', "
        "'2026-08-03T20:00:00.000Z')",
      );
    }
    if (version >= SchemaVersions.v3) {
      await db.customStatement(
        "INSERT INTO genres VALUES ('genre-1', 'Jazz', '2026-08-01T00:00:00.000Z')",
      );
      await db.customStatement(
        "INSERT INTO album_genres VALUES ('album-1', 'genre-1')",
      );
    }
    if (version >= SchemaVersions.v4) {
      await db.customStatement(
        "INSERT INTO album_discogs_releases VALUES ('album-1', 12345)",
      );
    }
    if (version >= SchemaVersions.v5) {
      await db.customStatement(
        "INSERT INTO tracks VALUES ('track-1', 'album-1', 'So What', "
        "'A1', 'A', 0, 545, '2026-08-01T00:00:00.000Z')",
      );
    }
  } finally {
    await db.close();
  }
}

Future<Map<String, Object?>> _snapshot(File file) async {
  final db = AppDatabase(NativeDatabase(file, enableMigrations: false));
  try {
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    final schema = await db
        .customSelect(
          'SELECT type, name, tbl_name, sql FROM sqlite_master '
          "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
        )
        .get();
    final data = <String, Object?>{};
    for (final entry in schema.where(
      (row) => row.read<String>('type') == 'table',
    )) {
      final table = entry.read<String>('name');
      final quoted = table.replaceAll('"', '""');
      final rows = await db
          .customSelect('SELECT * FROM "$quoted" ORDER BY rowid')
          .get();
      data[table] = rows.map((row) => row.data).toList();
    }
    return {
      'version': version.read<int>('user_version'),
      'schema': schema.map((row) => row.data).toList(),
      'data': data,
    };
  } finally {
    await db.close();
  }
}
