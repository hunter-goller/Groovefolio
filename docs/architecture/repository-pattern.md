# Repository pattern

Repositories are Groovefolio's persistence boundary.

## Current interfaces

- `IAlbumRepository`
- `IArtistRepository`
- `IPlayRepository`
- `INfcTagRepository`
- `IGenreRepository`

## Core rule

Callers provide domain values, not Drift companions. Repositories own generated IDs, timestamps, trimming/normalization, and database persistence objects.

Example shape:

```dart
final album = await albumRepository.create(
  title: title,
  artistId: artistId,
  releaseYear: year,
  label: label,
);
```

## Why

This keeps UI and services independent of Drift-specific companion types and makes repositories straightforward to fake in tests.

## Multi-repository workflows

When an operation spans several repositories, put it in a service rather than bloating one repository. `AlbumDeletionService` is the current example: it coordinates plays, NFC, artwork, and album removal.
