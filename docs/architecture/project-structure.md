# Project Structure

## Current layout

```text
lib/
├── db/
│   ├── migrations/
│   │   ├── migration_v1.dart
│   │   └── schema_versions.dart
│   ├── schema/
│   │   ├── albums.dart
│   │   ├── artists.dart
│   │   └── plays.dart
│   ├── app_database.dart
│   └── database_provider.dart
├── features/
│   ├── albums/screens/      # Collection, Add Record, Album Detail placeholders
│   ├── discover/screens/    # Discover placeholder
│   ├── plays/screens/       # Log Play placeholder
│   ├── stats/screens/       # Stats placeholder
│   └── route_test_buttons.dart
├── providers/               # Future shared feature/service state
├── repositories/
│   ├── album_repository.dart
│   └── artist_repository.dart
├── routing/
│   ├── app_routes.dart
│   └── router.dart
├── services/                # Empty scaffold
├── theme/                   # Empty scaffold
├── types/
│   └── side_played.dart
├── utils/                   # Empty scaffold
├── widgets/
│   ├── shared/              # Empty scaffold
│   └── ui/                  # Empty scaffold
└── main.dart
```

Versioned schema snapshots live outside `lib/`:

```text
drift_schemas/
└── drift_schema_v1.json
```

A directory containing only `.gitkeep` is planned structure, not implemented
functionality.

## Unmerged prototype layout

The VinylApp-018 branch contains additional files under `lib/dev/`, `lib/utils/`,
and `lib/widgets/`. Those files do not belong to the current layout until a
reviewed pull request merges them.

Do not copy the branch's widget list into current architecture diagrams or mark
the corresponding Trello cards complete.

## Folder responsibilities

### `lib/main.dart`

The composition root:

- starts Flutter;
- creates the root `ProviderScope`;
- eagerly watches `databaseProvider`;
- watches `routerProvider`;
- builds `MaterialApp.router`.

### `lib/routing/`

- `app_routes.dart` owns path constants and path builders.
- `router.dart` constructs and exposes GoRouter through Riverpod.

### `lib/db/`

- `schema/` holds Drift table definitions for Artists, Albums, and Plays.
- `migrations/` holds stable schema-version and migration code.
- `app_database.dart` registers tables, migration behavior, and SQLite opening.
- `database_provider.dart` exposes the database through Riverpod.

Generated `*.g.dart` files are ignored and regenerated locally and in CI.

### `drift_schemas/`

Stores committed Drift schema snapshots. These files are migration history and
must not be placed in `.gitignore`.

### `lib/features/`

Contains route-level presentation code and future feature-local state or
widgets. All current screens are placeholders.

`route_test_buttons.dart` is temporary and should be removed when the real
navigation shell and feature screens replace it.

### `lib/providers/`

Currently an empty scaffold for shared feature/service state. Repository
providers may live beside their repository when generated from that file, as
`albumRepositoryProvider` does today. VinylApp-043 will add feature-level
providers such as `albumsProvider` and `collectionFiltersProvider`.

### `lib/repositories/`

Contains persistence boundaries. `album_repository.dart` defines the Album
contract/implementation, while `artist_repository.dart` defines the Artist
contract/implementation. VinylApp-015 adds the Play repository.

### `lib/services/`

Currently empty. VinylApp-017 will add `PlayLoggingService`.

### `lib/theme/`

Currently empty. VinylApp-008 is deferred and will add design tokens and
`ThemeData`.

### `lib/widgets/`

Currently empty except for `.gitkeep`. Prototype widgets from VinylApp-018 are
not on `main`.

### `lib/types/`

Contains shared types needed across persistence and future feature layers.
`SidePlayed` currently lives here.

### `lib/utils/`

Currently empty. Add only small, pure, dependency-light helpers.

## Tests

```text
test/
├── db/
│   ├── app_database_test.dart
│   ├── artists_table_test.dart
│   ├── albums_table_test.dart
│   ├── plays_table_test.dart
│   └── migration_test.dart
├── repositories/
│   ├── album_repository_test.dart
│   └── artist_repository_test.dart
├── routing/
│   └── router_test.dart
└── widget_test.dart
```

## Import convention

Code under `lib/` uses package imports:

```dart
import 'package:vinyl_app/db/app_database.dart';
```

Dart does not require TypeScript-style path aliases. Package imports already
provide a stable project-root path.
