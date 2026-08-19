# Add Record

Route: `/album/new`

## Current fields
- artwork
- title (required)
- artist (required)
- year
- label
- genres

When a Discogs account is connected, the “Search Discogs to autofill” banner opens release search. Groovefolio shows up to five candidate releases; the user selects the exact release before title, artist, year, label, genres/styles, artwork, and the release tracklist are captured for the local record.

## Save flow
1. normalize/validate title + artist
2. find/create artist
3. create album through repository-backed mutation provider
4. when Discogs was selected, persist the exact release ID through `DiscogsReleaseLinkRepository`
5. persist the selected release tracklist transactionally through `TrackRepository`
6. persist selected/local-or-Discogs artwork through `ArtworkStorageService`
7. update album with stable artwork path
8. find/create selected genres and write AlbumGenres mappings
9. refresh providers and navigate to Collection

Artwork failures include cleanup/rollback logic so the database is not left linked to an unusable file.
