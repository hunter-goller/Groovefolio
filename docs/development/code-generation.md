# Code Generation

Vinyl App uses `build_runner` for Riverpod and Drift source generation.

## Generated sources

Examples include:

- `lib/routing/router.g.dart`
- `lib/db/database_provider.g.dart`
- `lib/db/app_database.g.dart`
- `lib/repositories/album_repository.g.dart`

All `*.g.dart` files are ignored by Git and regenerated in CI.

## Generate once

```bash
dart run build_runner build
```

Use this after:

- adding or changing an `@riverpod` provider;
- changing `@Riverpod` options such as `keepAlive`;
- adding or changing a Drift table;
- registering a table in `@DriftDatabase`;
- changing generated data-class annotations.

Current `build_runner` versions used by the project no longer need the old
`--delete-conflicting-outputs` option.

## Watch mode

During concentrated schema or provider work:

```bash
dart run build_runner watch
```

Stop watch mode before running another build process that may lock generated
files.

## Do not edit generated files

Generated files will be overwritten. Make changes in the annotated provider,
Drift table, database declaration, or repository source instead.

## Drift schema snapshots are different

`drift_schemas/drift_schema_v1.json` is generated, but unlike `*.g.dart`, it is
**version-controlled migration history** and must be committed.

When the schema version changes, export the new snapshot with:

```bash
dart run drift_dev schema dump lib/db/app_database.dart drift_schemas/
```

CI verifies that the committed snapshot matches the current schema.

## Common failure: companion naming

With this table:

```dart
@DataClassName('Album')
class Albums extends Table {}
```

Drift generates:

- `Album` for a row;
- `AlbumsCompanion` for inserts and updates.

The companion retains the plural table-class name. Likewise, `Plays` with
`@DataClassName('Play')` generates `Play` and `PlaysCompanion`.

## Dependency constraints

The repository currently pins compatible Riverpod, Drift, build-runner, and
source-generation versions. Do not upgrade one code generator in isolation.
Run generation, analysis, tests, schema verification, and the APK build after
dependency changes.
