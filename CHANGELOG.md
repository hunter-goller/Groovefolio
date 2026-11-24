# Changelog

All notable Groovefolio changes are recorded here. Historical ticket IDs retain the `VinylApp-###` prefix.

## Unreleased

### Robustness
- One damaged or unknown “side played” value no longer stops Collection, Stats and Discover from loading; it is read as a full-album play.
- Unknown links and paths show a “Page not found” screen with a way back to Collection instead of the router’s default error page.
### CI
- Pull requests now run checks only (about 4 minutes instead of 11); the debug and release builds run after each merge to `main`. The NFC Kotlin tests run on PRs that change Android code or packages, and on every merge.
- New **Release check** workflow: pushing a `v1.2.3` tag verifies the version matches `pubspec.yaml`, runs every check and build for that commit, and lists the commands to build the signed upload locally. The upload key stays off GitHub.

### Release builds
- CI builds the release App Bundle (the format Google Play requires) instead of a release APK, and fails if it isn't signed with the provided upload key.
### NFC security
- Only real tag taps log plays now. Other apps can no longer log fake plays by sending a `groovefolio://album/…` link to Groovefolio; such links open the app and log nothing.
### Server requests
- Request bodies sent to the Groovefolio server are now UTF-8 with `Content-Type: application/json; charset=utf-8`. Before, they were sent as Latin-1, which only worked because every current body is plain ASCII.
### Discogs connection
- “Checking connection…” now gives up after about 10 seconds even when the app has to refresh its server token first. Before, the refresh steps each had their own 30-second limit, so the check could take close to two minutes. Nothing is lost when it gives up; the next check finishes the refresh.
### Discogs
- Fixed Settings staying on "waiting" after connecting Discogs when returning to the app and the sign-in link arrived at the same time.
### Discogs import
- Collection import now waits and retries when Discogs asks it to slow down (up to a minute at a time, 3 retries per record) instead of stopping, and shows that it's waiting.
- Added Cancel import, and Back asks before stopping an import. Records already imported stay.
### Discogs connection
- Opening the app now quietly checks in with the Groovefolio server, at most once a day and only if Discogs is connected, so the connection doesn't silently end after a stretch of not using Discogs. If it has already ended, Settings now says why instead of just showing “Connect Discogs” again.
### Artwork
- Replacing a record's cover now shows the new picture right away on every screen. Before, the old cover could stay on screen until the app restarted, because the new file reuses the same path.
### Performance
- Cover art is decoded at the size it's shown (about 200 px for a list tile) instead of at full size (up to 1600 px). This uses much less memory and scrolls more smoothly through large collections.
### Data tidiness
- Artist and genre names now match regardless of case for accented letters too, so “BJÖRK” and “Björk” no longer become two artists. Accents still count: “Bjork” and “Björk” stay separate.
- Artists and genres no record uses any more are removed after you edit or delete a record, and cover files left behind by deleted records are cleaned up.

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
