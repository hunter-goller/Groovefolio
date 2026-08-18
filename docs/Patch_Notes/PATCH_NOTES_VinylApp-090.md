# VinylApp-090 — Discogs album autofill

## Added
- Connected-account Discogs search from Add Record
- Up to five exact release candidates with pressing metadata and cover previews
- Typed search-result and release-detail models; widgets never consume raw Discogs JSON
- Exact-release selection before autofill
- Autofill for title, artist, year, label, genres/styles, and artwork
- Discogs artwork downloaded through the shared authenticated client and persisted through `ArtworkStorageService`
- Schema v4 `album_discogs_releases` mapping for exact Discogs release IDs
- `DiscogsReleaseLinkRepository` for future duplicate/import/barcode flows
- Retryable rate-limit/network/API failure UI and an explicit no-results state
- Tests for Discogs JSON mapping, selection/autofill, failure/empty states, artwork bytes, release linkage, and v3 → v4 migration

## Behavior
Manual Add Record remains available when Discogs is disconnected or unavailable. Discogs metadata remains editable before save, and Groovefolio never silently chooses a pressing.
