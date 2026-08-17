# Changelog

All notable Groovefolio changes are recorded here. Historical ticket IDs retain the `VinylApp-###` prefix.

## Unreleased

### Branding and documentation
- Adopted **Groovefolio** as the user-facing product name.
- Renamed the GitHub repository to `hunter-goller/Groovefolio`.
- Refreshed architecture, feature, development, roadmap, setup, testing, and design documentation against the current schema-v3 application.
- Preserved the internal Dart package (`vinyl_app`), Android application ID, database filename, verification script name, and historical Trello IDs.

### Discogs foundation — VinylApp-106 Part 1
- Added OAuth 1.0a signing and request/access-token exchange boundaries.
- Added typed Discogs API/auth/network/rate-limit failures.
- Added secure OAuth credential storage using `flutter_secure_storage` 10.3.1.
- Added Riverpod providers for configuration, API client, credential store, auth service, and account state.
- Added deterministic OAuth signer tests.
- Pinned secure storage to the stable 10.3.1 release so Android remains compatible with the project's SDK 36 toolchain.

### Artwork and development data
- Added reusable artwork picker and persistent artwork storage.
- Added artwork replacement support to Add/Edit Record.
- Added destructive dev reset/seed runner with optional MusicBrainz/Cover Art Archive artwork lookup.
- Default dev reset targets 10 albums; `DEV_SEED_ALBUM_COUNT` supports larger stress datasets.

### Collection and statistics
- Added complete Add/Edit/Detail/Delete record workflows.
- Added many-to-many genre schema/repository/providers and genre UI.
- Added current-year/all-time statistics, monthly/yearly charts, genre breakdown, first vinyl, and most-played rankings.

## Historical milestones

- VinylApp-001–007: Flutter setup, analysis, CI, routing, Riverpod, Drift foundation.
- VinylApp-009–017: Artists/Albums/Plays persistence, repositories, providers, play logging service.
- VinylApp-040–041: NFC schema v2 and repository.
- VinylApp-098–103: schema v3 genres and genre-aware UI/statistics.
- VinylApp-046: production Stats screen.
- VinylApp-039: Edit Record.
- VinylApp-080: coordinated album deletion flow.
- VinylApp-104: all-time yearly plays chart.
- VinylApp-038: ArtworkStorageService.
- VinylApp-060: ArtworkPicker and artwork integration.

Detailed historical notes for selected older tickets remain under `docs/Patch_Notes/`.
