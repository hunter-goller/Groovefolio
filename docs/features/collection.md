# Collection

The Collection screen is the primary Groovefolio home screen and uses real local repository data.

## Current behavior
- shows album artwork, title, artist, genres/play-derived information through collection view models
- pull-to-refresh
- text search
- sort: Recent, A–Z, Most played
- genre filter bottom sheet
- Add Record FAB
- quick Log Play action
- bottom navigation to Collection / Stats / Discover
- loading, retry, and empty states

## Data flow

```text
CollectionScreen
  ↓ watches
albumsProvider + albumGenresProvider + collectionFiltersProvider
  ↓
Album/Artist/Play/Genre repositories
```

Recent and most-played behavior is derived from Plays rather than storing redundant last-played fields on Albums.
