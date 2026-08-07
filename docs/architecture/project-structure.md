# Project Structure

## Current layout on `main`

```text
lib/
├── db/
│   ├── migrations/          # Empty scaffold
│   ├── schema/
│   │   ├── albums.dart
│   │   └── artists.dart
│   ├── app_database.dart
│   └── database_provider.dart
├── features/
│   ├── albums/screens/      # Collection, Add Record, Album Detail placeholders
│   ├── discover/screens/    # Discover placeholder
│   ├── plays/screens/       # Log Play placeholder
│   ├── stats/screens/       # Stats placeholder
│   └── route_test_buttons.dart
├── providers/               # Empty scaffold
├── repositories/            # Empty scaffold
├── routing/
│   ├── app_routes.dart
│   └── router.dart
├── services/                # Empty scaffold
├── theme/                   # Empty scaffold
├── utils/                   # Empty scaffold
├── widgets/
│   ├── shared/              # Empty scaffold
│   └── ui/                  # Empty scaffold
└── main.dart
```

A directory containing only `.gitkeep` is planned structure, not implemented
functionality.

## Unmerged prototype layout

The VinylApp-018 branch contains additional files under `lib/dev/`,
`lib/utils/`, and `lib/widgets/`. Those files do not belong to the current
`main` layout until a reviewed pull request merges them.

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

- `schema/` holds Drift table definitions.
- `migrations/` is reserved for VinylApp-012.
- `app_database.dart` registers tables and opens SQLite.
- `database_provider.dart` exposes the database through Riverpod.

Generated `*.g.dart` files are ignored and regenerated locally and in CI.

### `lib/features/`

Contains route-level presentation code and future feature-local state or
widgets. All current screens are placeholders.

`route_test_buttons.dart` is temporary and should be removed when the real
navigation shell and feature screens replace it.

### `lib/providers/`

Currently empty. VinylApp-016 will add repository providers. VinylApp-043 will
add feature-level providers such as `albumsProvider` and
`collectionFiltersProvider`.

### `lib/repositories/`

Currently empty. VinylApp-013, 014, and 015 will add Album, Artist, and Play
repositories.

### `lib/services/`

Currently empty. VinylApp-017 will add `PlayLoggingService`.

### `lib/theme/`

Currently empty. VinylApp-008 is deferred and will add design tokens and
`ThemeData`.

### `lib/widgets/`

Currently empty except for `.gitkeep`. Prototype widgets from VinylApp-018 are
not on `main`.

Shared widgets belong here only after their own acceptance criteria are met and
the implementation is merged.

### `lib/utils/`

Currently empty. Add only small, pure, dependency-light helpers.

## Tests

```text
test/
├── db/
│   ├── app_database_test.dart
│   ├── artists_table_test.dart
│   └── albums_table_test.dart
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
