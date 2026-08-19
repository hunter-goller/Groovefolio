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

Supports title, artist, year, label, genres, and artwork replacement. Existing purchase metadata is preserved. The NFC rewrite option is currently a deferred UI hook; actual NFC writing is not implemented yet.

## Delete Record
`AlbumDeletionService` coordinates:
- deletion of play rows
- deletion of linked NFC association
- persisted artwork deletion
- album deletion

AlbumGenres mappings, Discogs release links, and Tracks rows are removed by database cascade. The UI confirms the album title and number of logged plays before deletion.
