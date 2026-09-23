# Album detail, edit, and delete

## Album Detail
Route: `/album/:id`

Shows:
- artwork
- title + artist
- release year/label when present
- genre chips
- persistent tracklist, grouped by vinyl side when Discogs position metadata is available
- play count / derived listening information
- recent play history
- Log first/another play action
- Edit Record menu action
- Delete Record menu action

## Edit Record
Route: `/album/:id/edit`

Supports title, artist, year, label, genres, and artwork replacement. Existing purchase metadata is preserved. Album Details can link a tag to an existing record or rewrite/replace its linked tag on a supported Android device.

## Delete Record
`AlbumDeletionService` coordinates:
- album deletion in the database, cascading to plays, NFC association, genres, Discogs link, and tracks
- best-effort persisted artwork cleanup after the database commit

AlbumGenres mappings, Discogs release links, and Tracks rows are removed by database cascade. The UI confirms the album title and number of logged plays before deletion.
