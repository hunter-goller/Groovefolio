# Repository pattern

Repositories are Groovefolio's persistence boundary.

## Current interfaces

- `IAlbumRepository`
- `IArtistRepository`
- `IPlayRepository`
- `INfcTagRepository`
- `IGenreRepository`
- `IDiscogsReleaseLinkRepository`
- `ITrackRepository`

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

When an operation spans several repositories, put it in a service rather than bloating one repository. `RecordWriteService` coordinates add/edit/import writes in one transaction. `AlbumDeletionService` deletes an album and lets database cascades remove associated rows, then cleans up artwork.
