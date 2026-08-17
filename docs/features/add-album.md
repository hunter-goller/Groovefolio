# Add Record

Route: `/album/new`

## Current fields
- artwork
- title (required)
- artist (required)
- year
- label
- genres

The current screen includes a visual “Search Discogs to autofill” banner, but Discogs search is intentionally deferred to `VinylApp-090`.

## Save flow
1. normalize/validate title + artist
2. find/create artist
3. create album through repository-backed mutation provider
4. persist selected artwork through `ArtworkStorageService`
5. update album with stable artwork path
6. find/create selected genres and write AlbumGenres mappings
7. refresh providers and navigate to the new album

Artwork failures include cleanup/rollback logic so the database is not left linked to an unusable file.
