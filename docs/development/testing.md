# Testing Strategy

## Current coverage

### Database smoke test

`test/db/app_database_test.dart` opens an in-memory database and executes a
simple query.

### Artist table test

`test/db/artists_table_test.dart` inserts and reads an artist.

### Album table tests

`test/db/albums_table_test.dart` verifies:

- Insert and select with a valid artist reference.
- Failure when the referenced artist does not exist.

### Router provider tests

`test/routing/router_test.dart` verifies:

- Riverpod returns a `GoRouter`.
- The router provider can be overridden for testing.

### Application smoke test

`test/widget_test.dart` pumps the app under `ProviderScope` and verifies the
initial Collection screen.

## In-memory database pattern

```dart
final db = AppDatabase(NativeDatabase.memory());
addTearDown(db.close);
```

An in-memory database is fast, isolated, and does not depend on a device
filesystem. Prefer `addTearDown` or `tearDown` so resources close even when a test
fails.

## Planned test layers

### Schema and migration tests

- Plays table and album foreign key
- Fresh schema creation
- Schema snapshot generation
- Step-up migration tests for every version

### Repository tests

Every repository method should be tested against a clean in-memory database,
including sorting, filtering, case-insensitive matching, deletion, and
aggregations.

### Service tests

Services should use fake repositories and adapters. Tests should verify business
outcomes, not widget details.

### Provider tests

Use `ProviderContainer` overrides to verify state transitions and dependency
replacement.

### Widget tests

Cover loading, empty, error, and populated states as real screens replace
placeholders.

### Integration tests

Planned core flows:

- Add an artist and album, then view the collection.
- Open Album Detail from the collection.
- Log a play and observe updated history/statistics.
- Edit and delete an album safely.
- Associate and scan an NFC tag on supported hardware.

## Commands

```bash
flutter test
flutter test test/db/albums_table_test.dart
flutter test --coverage
```

Coverage percentage is not currently a merge gate. Meaningful behavior coverage
is more important than maximizing a number.
