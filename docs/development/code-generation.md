# Code Generation

Vinyl App uses `build_runner` for Riverpod and Drift source generation.

## Generated sources

Examples include:

- `lib/routing/router.g.dart`
- `lib/db/database_provider.g.dart`
- `lib/db/app_database.g.dart`

All `*.g.dart` files are ignored by Git and regenerated in CI.

## Generate once

```bash
dart run build_runner build --delete-conflicting-outputs
```

Use this after:

- Adding or changing an `@riverpod` provider
- Changing `@Riverpod` options such as `keepAlive`
- Adding or changing a Drift table
- Registering a table in `@DriftDatabase`
- Changing generated data-class annotations

## Watch mode

During concentrated schema or provider work:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

Stop watch mode before running another build process that may lock generated
files.

## Do not edit generated files

Generated files will be overwritten. Make changes in the annotated provider,
Drift table, or database declaration instead.

## Common failure: companion naming

With this table:

```dart
@DataClassName('Album')
class Albums extends Table {}
```

Drift generates:

- `Album` for a row
- `AlbumsCompanion` for inserts and updates

The companion retains the plural table-class name.

## Dependency constraints

The repository currently pins compatible Riverpod, Drift, build-runner, and
source-generation versions. Do not upgrade one code generator in isolation.
Run the full generation, analysis, tests, and APK build after dependency changes.
See [ADR-0006](../decisions/ADR-0006-native-drift-connection.md).
