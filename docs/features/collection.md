# Collection

- Route: `/`
- Trello task: VinylApp-018
- Current status on `main`: Placeholder
- Trello status: On Hold
- Prototype status: Unmerged and backed by fake data

## Purpose

The Collection screen is the primary view of the user's records. It should make
recent listening activity visible while supporting search, sorting, filtering,
and collection management.

## Trello acceptance criteria

- Show all albums sorted by last played by default.
- Update the list when filter chips change.
- Show an empty state when the collection is empty.
- Navigate to `/album/:id` when an album is tapped.
- Re-fetch real data during pull-to-refresh.
- Use `albumsProvider` and `collectionFiltersProvider`.

## Current `main` implementation

`CollectionScreen` currently displays:

- an AppBar title;
- placeholder text;
- temporary `RouteTestButtons`.

It does not read Artists or Albums from Drift. It does not sort, filter, refresh,
or display a real collection.

## Unmerged VinylApp-018 prototype

The prototype branch is useful visual reference, but it is not production
implementation because it uses:

- `fakeAlbums`;
- local `_sortBy` widget state;
- a delayed fake refresh;
- individual display fields instead of the final repository/provider model;
- hard-coded styling before VinylApp-008.

The branch also contains early widget versions. Those files are not on `main`.

## Required dependencies

### Database and persistence

- VinylApp-011 — Plays table
- VinylApp-012 — Initial Drift migration
- VinylApp-013 — AlbumRepository
- VinylApp-014 — ArtistRepository
- VinylApp-015 — PlayRepository
- VinylApp-016 — Repository providers

### Feature state

VinylApp-043 creates the required feature providers:

- `albumsProvider`
- `albumProvider(id)`
- `recentlyPlayedProvider`
- `playCountProvider(albumId)`
- `collectionFiltersProvider`

VinylApp-009 and VinylApp-010 only created tables. They did not create these
providers.

### Theme and widgets

- VinylApp-008 — Theme and design tokens
- VinylApp-021 — AlbumListTile
- VinylApp-023 — SectionHeader
- VinylApp-024 — BottomNavBar
- VinylApp-026 — GenreChip
- VinylApp-032 — PrimaryButton
- VinylApp-058 — SummaryBar
- VinylApp-059 — FilterChipRow
- VinylApp-069 — Empty states

## Expected data shape

The raw Drift `Album` row stores an `artistId` and does not contain an artist
name, genre list, play count, or last-played timestamp. Collection UI therefore
needs a repository/provider result that combines the required data, for example:

```dart
class CollectionAlbum {
  final Album album;
  final Artist artist;
  final int playCount;
  final DateTime? lastPlayedAt;
}
```

The final type may differ, but the UI should not reconstruct these joins and
aggregations itself.

## Required UI states

- Loading
- Empty collection
- Populated collection
- Search/filter with no matches
- Database error with retry action
- Refreshing

## Definition of done

VinylApp-018 should only move to Done when fake data and local-only state are
removed, the screen is wired to the real provider chain, its acceptance criteria
pass, and the implementation is merged into `main`.
