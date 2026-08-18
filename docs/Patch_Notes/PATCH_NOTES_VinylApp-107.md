# VinylApp-107 — Import Discogs collection

## Added
- Connected-account **Import Discogs collection** action in Settings
- Dedicated review/import screen before any local writes begin
- Paginated Discogs collection reads through the shared authenticated API client
- Vinyl-only collection filtering
- Exact Discogs release-ID duplicate detection
- Possible local duplicate classification using normalized artist + title matching
- New releases selected by default; possible duplicates require explicit user selection
- Per-release exact metadata lookup before import
- Local Artist, Album, Genre/style, artwork, and Discogs release-link creation
- Artwork persistence through `ArtworkStorageService`
- Import progress for large collections
- Per-release failure isolation and end-of-import failure/warning summary
- Tests for collection JSON mapping, pagination, duplicate classification, import mapping, partial failures, and review UI

## Behavior
Groovefolio remains local-first. Importing copies selected Discogs release data into the local SQLite collection; the Discogs connection is not required to keep using imported records afterward. Existing exact Discogs release IDs are not imported twice, and possible non-ID local matches are never silently overwritten.
