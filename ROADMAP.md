# Vinyl App Roadmap

This roadmap summarizes implementation order. Trello remains the detailed task
board; this document is the stable project overview.

## Status legend

- ✅ Complete
- 🚧 Next or actively in progress
- ⏸ On hold or intentionally deferred
- ⬜ Planned
- 🧪 Prototype exists outside `main`
- 🔭 Future exploration

## 1. Foundation and database

- ✅ VinylApp-001 — Flutter project and initial folder structure
- ✅ VinylApp-002 — Strict analysis and lint configuration
- ✅ VinylApp-003 — GitHub repository, branch protection, and PR template
- ✅ VinylApp-004 — GitHub Actions CI pipeline
- ✅ VinylApp-005 — GoRouter route setup
- ✅ VinylApp-006 — Riverpod provider architecture
- ✅ VinylApp-007 — Drift and SQLite database setup
- ⏸ VinylApp-008 — Theme, design tokens, and dark mode
- ✅ VinylApp-009 — Albums table
- ✅ VinylApp-010 — Artists table
- ✅ VinylApp-011 — Plays table
- ✅ VinylApp-012 — Initial Drift migration and schema export

## 2. Core data layer

Complete these in order:

1. ✅ VinylApp-013 — AlbumRepository
2. ✅ VinylApp-014 — ArtistRepository
3. ✅ VinylApp-015 — PlayRepository
4. ✅ VinylApp-040 — NFC tag table + schema v2 migration
5. ✅ VinylApp-041 — NfcTagRepository
6. 🚧 VinylApp-016 — Complete repository-provider layer
7. ⬜ VinylApp-017 — PlayLoggingService

VinylApp-013 introduces `albumRepositoryProvider`, VinylApp-014 introduces
`artistRepositoryProvider`, and VinylApp-015 introduces `playRepositoryProvider`.
VinylApp-040 and 041 complete the NFC persistence dependency needed by 016.
VinylApp-016 standardizes all four repository providers behind a central import
surface and adds ProviderContainer override coverage for every repository dependency.

VinylApp-017 is required for the play-logging workflow. It is not the direct
provider dependency used by the read-only Collection screen, but it remains part
of the ordered core data-layer work.

## 3. Providers required by Collection

- ⬜ VinylApp-043 — Riverpod service and feature providers

VinylApp-043 is the direct task that creates:

- `albumsProvider`
- `albumProvider(id)`
- `recentlyPlayedProvider`
- `playCountProvider(albumId)`
- `collectionFiltersProvider`

VinylApp-018 cannot satisfy its real-data acceptance criteria until these
providers and their repositories exist.

## 4. Theme and Collection UI

- ⏸ VinylApp-008 — Theme and design tokens
- ⏸ VinylApp-018 — Collection Screen
- ⏸ VinylApp-021 — AlbumListTile
- ⏸ VinylApp-023 — SectionHeader
- ⏸ VinylApp-024 — BottomNavBar
- ⏸ VinylApp-026 — GenreChip
- ⬜ VinylApp-032 — PrimaryButton
- ⏸ VinylApp-058 — SummaryBar
- ⏸ VinylApp-059 — FilterChipRow
- ⬜ VinylApp-069 — Empty states

### VinylApp-018 prototype status

A separate VinylApp-018 branch contains a visual Collection prototype and early
versions of several widgets. That work:

- uses `fakeAlbums`;
- stores sorting in local widget state;
- does not use `albumsProvider` or `collectionFiltersProvider`;
- does not read Drift through repositories;
- is not merged into `main`.

The prototype is reference material, not completed functionality.

## 5. First end-to-end collection flow

After the prerequisites above:

- ⬜ VinylApp-018 — Connect Collection to real providers and satisfy acceptance criteria
- ⬜ VinylApp-019 — Add Record Screen
- ⬜ VinylApp-039 — Edit Album Screen
- ⬜ VinylApp-048 — Album Detail Screen
- ⬜ Create, update, delete, search, and filter real collection records
- ⬜ Replace temporary route-testing controls with the navigation shell

## 6. Listening and statistics

- ⬜ VinylApp-020 — Log Play Screen
- ⬜ Play history by album
- ⬜ Collection-level recently played list
- ⬜ Full album / Side A / Side B tracking in the UI
- ⬜ VinylApp-044 — StatsService
- ⬜ VinylApp-046 — Stats Screen

## 7. Discovery and signature features

- ⬜ VinylApp-047 — Discover Screen
- ⬜ Rediscovery suggestions
- ⬜ Personalized recommendations
- ⬜ Album Wrapped
- ⬜ Collection ranking and listening-pattern insights
- ⬜ Similar-album suggestions

## 8. NFC

- ✅ VinylApp-040 — NFC schema + v2 migration
- 🚧 VinylApp-041 — NfcTagRepository
- ⬜ NFC capability detection and permission handling
- ⬜ Associate a tag with an album
- ⬜ Scan a tag and resolve its album
- ⬜ Confirm and log a play from a scan
- ⬜ Graceful fallback on unsupported devices

## 9. Quality and release

- ⬜ VinylApp-033 — Test framework setup
- ⬜ VinylApp-034 — AlbumRepository unit-test follow-up card (013 already includes baseline repository coverage)
- ⬜ VinylApp-035 — PlayRepository unit-test hardening (015 includes baseline repository coverage)
- ⬜ VinylApp-036 — PlayLoggingService unit tests
- ⬜ Widget tests for primary states
- ⬜ Integration tests for core user flows
- ⬜ Accessibility review
- ⬜ Performance and database query review
- ⬜ Privacy policy
- ⬜ App icon, splash screen, and store assets
- ⬜ Debug/release build configuration
- ⬜ Internal Android test release
- ⬜ Google Play release preparation

## Future integrations

- 🔭 Discogs metadata lookup
- 🔭 Barcode lookup
- 🔭 Optional Spotify or Last.fm metadata enrichment
- 🔭 Backup and restore
- 🔭 Cross-device sync
- 🔭 Export and import

The project remains local-first. Future network integrations should enrich the
local experience rather than make basic collection or play tracking depend on a
remote service.
