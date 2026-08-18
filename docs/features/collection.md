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
- optional Discogs collection import is launched from Settings when a Discogs account is connected

## Data flow

```text
CollectionScreen
  ↓ watches
albumsProvider + albumGenresProvider + collectionFiltersProvider
  ↓
Album/Artist/Play/Genre repositories
```

Recent and most-played behavior is derived from Plays rather than storing redundant last-played fields on Albums.


## Discogs collection import

`VinylApp-107` keeps the local database authoritative while making initial collection setup faster:

- every Discogs collection page is read before writing
- non-vinyl items are ignored
- exact Discogs release IDs already linked locally are disabled as duplicates
- title + artist matches without a Discogs link are shown as “Review” and are not selected automatically
- only releases explicitly selected in the review screen are written
- each imported release maps through repository/service boundaries for artist, album, genre/style, artwork, and Discogs release identity
- one failed release does not stop the remaining import
