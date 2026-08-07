# Add and Edit Album

- Add route: `/album/new`
- Current status: Add Record placeholder; edit flow not implemented

## Purpose

Allow a collector to create a complete record entry without requiring a network
service.

## Intended fields

- Title
- Artist
- Release year
- Label
- Artwork
- Purchase date
- Purchase price
- Additional condition or edition fields as the schema evolves
- Optional NFC association

## Intended flow

1. Enter title and artist.
2. Reuse an existing artist case-insensitively or create one.
3. Enter optional metadata and choose artwork.
4. Validate required fields.
5. Persist artist and album atomically enough to avoid orphaned data.
6. Return to the collection or new album detail page.

## Planned dependencies

- ArtistRepository `findOrCreate`
- AlbumRepository `create` and `update`
- Form provider/state
- Artwork picker and form widgets
- Optional future Discogs lookup adapter

## Error handling

- Preserve form data after a validation or database error.
- Explain required fields near the relevant input.
- Do not require internet access.
- Handle artwork permission or file failures gracefully.
