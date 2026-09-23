# Development seed data

Groovefolio includes debug-only local seed tooling for UI/statistics development.

## Non-destructive seed

```powershell
flutter run -t lib/dev/seed_main.dart
```

This reuses matching seeded albums and backfills seed data without intentionally clearing the existing collection.

## Destructive reset + artwork seed

```powershell
flutter run -t lib/dev/reset_seed_main.dart
```

Default album count: **10**.

The reset:
1. deletes artwork referenced by existing albums
2. clears AlbumGenres, Plays, NfcTags, Albums, Genres, and Artists in dependency-safe order
3. recreates seed albums through real repositories/services
4. assigns genres and historical/recent plays
5. optionally looks up covers through MusicBrainz + Cover Art Archive

Artwork lookup is development-only and failures do not abort the entire seed.

## Collection size

Both seed service functions accept an `albumLimit` argument, defaulting to **10**. The checked-in entry points use that default. To change size for local stress testing, explicitly pass a different `albumLimit` at the call in the development entry point; the seed takes at most that many records from its finite seed pool (non-positive limits use one).

`DEV_SEED_ALBUM_COUNT` is **not** read by the current runners. Passing that old documented build define has no effect. This page describes the existing code, not a new configurable seed feature.

## Important
This runner is destructive by design. Use it only against development app data.

Both entry points use the same database and application ID as the ordinary app. A debug build does not create a separate safe copy of your collection. The seed reset removes referenced artwork **before** its database transaction; it is a disposable development helper, not the production deletion/recovery workflow. The Settings debug reset follows a different DB-first policy through `LocalDataResetService`. Stop the seed runner and launch normal `flutter run` afterward.
