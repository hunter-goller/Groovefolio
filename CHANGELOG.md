# Changelog

All notable Groovefolio changes are recorded here. Historical ticket IDs retain the `VinylApp-###` prefix.

## Unreleased

### Tutorial fixes from phone testing
- The spotlight now lands on the right place after a screen slides in (it was off to the side on the Discover tab).
- The tutorial waits behind dialogs, such as swipe practice’s “Nice move!”, instead of drawing its hand and ring over them.
- During a Discogs import the tutorial steps aside, and comes back to celebrate when the import finishes.
- The gold record counts bonus badges separately: “all 4 main tracks and a bonus one”.

### Tutorial tracks (part 3b)
- Scripted the Side B tracks: NFC (record menu, Link NFC tag, then the write dialog) and swipe (swipe, Edit or Delete, then a Practice mode Delete that changes nothing). The backup track is scripted and appears once the backup feature ships.
- Show me now returns to where the track started, at step 1; menu steps outline the item and keep the bubble clear of the menu.

### Tutorial tracks (part 3a)
- Turned on the game-style tutorial for everyone and removed the old 8-step walkthrough.
- Added the spotlight guide: dims all but one real control, a coach bubble with Pause and Skip, a short hand demonstration (still with reduced motion), Show me when off track, and Add by hand instead on the Discogs path. Side A tracks are fully scripted.

### Tutorial tracks (part 2)
- Added the game-style tutorial screens behind `GROOVEFOLIO_NEW_TUTORIAL` (off by default): Welcome, the Track 1 Discogs-or-by-hand choice, the NFC intro, a track hint bar, Track complete celebrations with badges, the Getting started tracklist and the Gold record.

### Tutorial tracks (part 1)
- Added the progress model for the upcoming game-style tutorial: tracks, badges, locking, a gold record, and auto-completion from existing records, plays and NFC tags. Stored on the device only. No visible change yet.
- If first-run status can't be read from secure storage, the collection now opens instead of a full-screen error with only Retry.
### Backup and restore
- Added Settings → Back up collection: a versioned `.zip` with every local table and stored covers, saved wherever the user chooses through the system Save dialog.
- Added **Save a copy of my data** to the startup error screen: copies the raw database and covers to a rescue file without opening the database.
- Added Settings → Restore from backup for an empty collection, with a summary and confirmation, one-transaction restore and validation of damaged, foreign or newer-version files.

### Documentation and release preparation
- Organized historical overlay instructions under `docs/archive/apply-notes/` and updated living documentation against the current app.
- Selected the permanent Android application ID `app.groovefolio` before public release and required explicit upload signing for release builds. The developer's real upload key and AAB remain outstanding.

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

### Discogs catalog and import — VinylApp-090/107/105
- Added vinyl-only Discogs release search and editable Add Record autofill.
- Added connected-account Discogs collection import with pagination and duplicate protection.
- Added schema v5 tracklists, transactional TrackRepository replacement, Discogs track position/side/duration parsing, and Album Detail tracklist rendering.

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
