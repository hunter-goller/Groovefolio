# Testing Strategy

## Current coverage

### Database smoke test

`test/db/app_database_test.dart` opens an in-memory database and executes a
simple query.

### Artist table test

`test/db/artists_table_test.dart` inserts and reads an artist.

### Album table tests

`test/db/albums_table_test.dart` verifies:

- insert/select with a valid artist reference;
- failure when the referenced artist does not exist.

### Plays table tests

`test/db/plays_table_test.dart` verifies play insertion, album filtering, and
`SidePlayed` enum persistence.

### Migration test

`test/db/migration_test.dart` verifies:

- an empty database creates Artists, Albums, and Plays;
- generated table accessors can query the created schema;
- `PRAGMA user_version` is set to v1.

### AlbumRepository tests

`test/repositories/album_repository_test.dart` uses an in-memory Drift database
to verify:

- `create()`;
- `findAll()`;
- `findById()` including missing IDs;
- `update()`;
- `delete()`;
- title search case-insensitively;
- artist-name search case-insensitively;
- empty search behavior.

### ArtistRepository tests

`test/repositories/artist_repository_test.dart` uses an in-memory Drift database
to verify:

- creation through `findOrCreate()`;
- case-insensitive idempotent deduplication;
- whitespace normalization;
- blank-name rejection;
- `findById()` including missing IDs;
- `findAll()`.

### Router provider tests

`test/routing/router_test.dart` verifies:

- Riverpod returns a `GoRouter`;
- the router provider can be overridden for testing.

### Application smoke test

`test/widget_test.dart` pumps the app under `ProviderScope` and verifies the
initial Collection screen.

## In-memory database pattern

```dart
final db = AppDatabase(NativeDatabase.memory());
addTearDown(db.close);
```

An in-memory database is fast, isolated, and does not depend on a device
filesystem. Prefer `addTearDown` or `tearDown` so resources close even when a
test fails.

## Planned test layers

### Schema and migration tests

Every future schema version should add a step-up migration test from the prior
committed snapshot.

### Repository tests

PlayRepository should follow the existing AlbumRepository and ArtistRepository
pattern: every public method covered against a clean in-memory database,
including aggregation behavior where relevant.

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
flutter test test/repositories/album_repository_test.dart
flutter test test/repositories/artist_repository_test.dart
flutter test --coverage
```

Coverage percentage is not currently a merge gate. Meaningful behavior coverage
is more important than maximizing a number.
