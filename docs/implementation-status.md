# Current implementation status

This document describes the current Groovefolio implementation baseline.

## Complete / working

### App foundation
- Flutter/Dart project
- strict analyzer/lints
- GitHub Actions CI
- go_router routes
- Riverpod + generated providers
- Drift/SQLite local database
- light/dark Material theme and design tokens

### Database
Current schema is **v5**.

- v1: Artists, Albums, Plays
- v2: NfcTags
- v3: Genres, AlbumGenres
- v4: AlbumDiscogsReleases
- v5: Tracks

Fresh databases intentionally apply the frozen migrations in order. Upgrades apply only the missing migration steps. Foreign keys are enabled for each SQLite connection.

### Data/repository layer
- AlbumRepository
- ArtistRepository
- PlayRepository
- NfcTagRepository
- GenreRepository
- DiscogsReleaseLinkRepository
- TrackRepository
- repository providers for dependency injection/testing

Repositories create IDs/timestamps and Drift persistence objects internally.

### Services
- PlayLoggingService
- StatsService
- ArtworkStorageService
- AlbumDeletionService
- DiscogsApiClient / DiscogsAuthService OAuth foundation and account connection flow
- DiscogsCatalogService search/release/artwork/collection workflow
- DiscogsCollectionImportService pagination, duplicate review, local import, tracklist persistence, progress, and partial-failure workflow

### Collection UX
- Collection screen using real local data
- search by collection text
- Recent / A–Z / Most played sorting
- genre display and genre filter
- Add Record
- Edit Record
- Album Detail
- Delete Record confirmation/cleanup
- artwork pick/replace/persist
- recent play history on album detail
- persistent Discogs tracklists on Album Detail with vinyl-side grouping
- connected-account Discogs collection import with duplicate review and progress

### Play logging
- select/search album
- choose date/time
- choose full album, side A, or side B
- log through PlayLoggingService
- refresh collection/play-count providers

### Statistics
- current year / all time
- total records, total plays, average/week
- current month plays
- first vinyl
- monthly current-year chart
- yearly all-time chart
- play-weighted genre breakdown
- most-played albums

### Development tooling
- non-destructive seed runner
- destructive reset + seed runner
- default 10-record seed
- variable `DEV_SEED_ALBUM_COUNT`
- optional MusicBrainz/Cover Art Archive cover lookup

## Discogs connection

### VinylApp-106 — Discogs connection
Parts 1 and 2 provide OAuth signing, request/access credential exchange, secure token storage, identity lookup, typed failures, Settings connection UI, external browser authorization, custom-scheme callback handling, connected username display, and disconnect UX.

### VinylApp-090 — Discogs release search/autofill
Add Record can search vinyl releases, select an exact pressing, autofill editable metadata/artwork, and persist the exact Discogs release ID.

### VinylApp-107 — Discogs collection import
Settings exposes a connected-account import flow with collection pagination, vinyl-only filtering, exact-ID duplicate detection, possible-local-match review, progress, artwork/genre import, and per-release failure summaries. VinylApp-105 extends imported releases with persistent tracklists.

### VinylApp-105 — Discogs tracklists
Schema v5 adds album tracks. Exact Discogs release details parse ordered positions, vinyl sides, and durations; Add Record and collection import persist them transactionally through TrackRepository; Album Detail renders side-grouped tracklists and a clean empty state for manual records.

## Not implemented yet
- production Discover/recommendations
- NFC scan-to-log UI and auto-log flow (Android permission, platform adapter,
  typed write/scan service, availability foundation, Add Record writing, and
  existing-record link/replace actions are implemented in
  VinylApp-045/064/065)
- barcode scanning
- final icon/splash/release polish

## Tests
The repository has database, migration, repository, provider, service, screen, and shared-widget tests. The project verification script is the expected pre-push source of truth.
