# Current implementation status

This document describes the post-`VinylApp-106` Part 1 baseline used for the Groovefolio documentation/branding refresh.

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
Current schema is **v3**.

- v1: Artists, Albums, Plays
- v2: NfcTags
- v3: Genres, AlbumGenres

Fresh databases intentionally apply the frozen migrations in order. Upgrades apply only the missing migration steps. Foreign keys are enabled for each SQLite connection.

### Data/repository layer
- AlbumRepository
- ArtistRepository
- PlayRepository
- NfcTagRepository
- GenreRepository
- repository providers for dependency injection/testing

Repositories create IDs/timestamps and Drift persistence objects internally.

### Services
- PlayLoggingService
- StatsService
- ArtworkStorageService
- AlbumDeletionService
- DiscogsApiClient / DiscogsAuthService Part 1 foundation

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

## In progress

### VinylApp-106 — Discogs connection
Part 1 is merged: OAuth signing, request/access credential exchange, secure token storage, identity lookup boundary, providers, typed failures.

Part 2 still needs to connect this foundation to Settings, browser authorization, app callback/deep link, and disconnect UX.

## Not implemented yet
- production Discover/recommendations
- NFC device permissions/write/read/auto-log flows
- Discogs search/autofill
- Discogs collection import
- Tracks schema/import
- barcode scanning
- final icon/splash/release polish

## Tests
The repository has database, migration, repository, provider, service, screen, and shared-widget tests. The project verification script is the expected pre-push source of truth.
