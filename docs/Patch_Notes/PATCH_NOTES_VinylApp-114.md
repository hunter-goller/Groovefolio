# VinylApp-114 — Engineering audit hardening

VinylApp-114 addresses the highest-value development-stage findings from the August 20, 2026 engineering audit without turning the project into a release pipeline.

## Database reliability

Schema v6 rebuilds `plays` and `nfc_tags` so album-owned rows use `ON DELETE CASCADE`, and adds `plays_album_played_at_idx` on `(album_id, played_at)`. Frozen v1-v5 migrations remain unchanged.

Album deletion now relies on one atomic album delete for database-owned associations. Artwork is removed only after the DB commit, making an orphaned image preferable to a surviving album that lost its artwork.

## Atomic record workflows

`RecordWriteService` provides one transaction boundary for the database parts of Add Record, Edit Record, and Discogs collection import. Artist creation/reuse, album writes, exact Discogs release linkage, tracklists, and genre mappings now commit or roll back together. Filesystem artwork remains a post-transaction concern because SQLite cannot atomically commit filesystem writes.

## Discogs transport hardening

`DiscogsApiClient` now validates artwork URLs against trusted HTTPS Discogs image hosts and downloads CDN artwork without forwarding the user's OAuth Authorization header. It also adds explicit request timeouts, bounded response sizes, GET retries with backoff, `Retry-After` handling, typed malformed JSON/text failures, and safer network error messages.

Collection import aborts on systemic authentication, rate-limit, or network failures instead of immediately repeating the same failure for every remaining release.

## Release configuration check

The main Android manifest now owns `android.permission.INTERNET`. GitHub Actions additionally compiles a release APK to catch release-only configuration regressions. The build is not uploaded or published as an artifact, and production signing remains deferred until Play Store readiness work.
