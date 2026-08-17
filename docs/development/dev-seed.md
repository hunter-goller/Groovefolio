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

## Stress size

```powershell
flutter run -t lib/dev/reset_seed_main.dart --dart-define=DEV_SEED_ALBUM_COUNT=60
```

Any positive count may be supplied; the seed selects from the available seed pool.

## Important
This runner is destructive by design. Use it only against development app data.
