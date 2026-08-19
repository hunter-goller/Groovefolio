# VinylApp-105 — Track schema + Discogs tracklist import

## What changed

- Added schema v5 `Tracks` with ordered album track metadata, Discogs position, inferred side, duration, timestamps, and album cascade cleanup.
- Added `TrackRepository` with deterministic reads and transactional full-tracklist replacement.
- Discogs release parsing now maps tracklists while skipping non-track headings and flattening sub-tracks.
- Add Record persists a selected Discogs pressing’s tracklist after album creation.
- Discogs collection import now persists tracklists for each imported release.
- Album Details displays tracklists grouped by side when Discogs positions identify sides; otherwise it preserves release order.
- Manual records show a clean no-tracklist state.
- Added migration, table, repository, model, service, provider, Add Record, and Album Detail regression coverage.

## Validation

Run `./tools/verify_vinylapp_012.ps1`, then live-test one Discogs-backed album on Android.
