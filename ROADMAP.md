# Groovefolio roadmap

Groovefolio is being built as a local-first vinyl collection and listening-history app. Historical Trello IDs retain the `VinylApp-###` prefix.

## Foundation — implemented

- ✅ Flutter project, analyzer/lints, GitHub Actions, go_router, Riverpod, Drift
- ✅ schema v1: Artists + Albums + Plays
- ✅ schema v2: NfcTags
- ✅ schema v3: Genres + AlbumGenres
- ✅ repositories for albums, artists, plays, NFC tags, and genres
- ✅ repository/provider boundaries with IDs/timestamps owned below the UI
- ✅ PlayLoggingService
- ✅ theme/tokens/shared UI foundation

## Collection — implemented

- ✅ Collection screen with search and sorting
- ✅ genre display/filtering
- ✅ Add Record
- ✅ Edit Record
- ✅ Album Detail
- ✅ coordinated Delete Record flow
- ✅ artwork picker and persistent artwork storage
- ✅ manual play logging and album play history

## Statistics — implemented

- ✅ StatsService
- ✅ current-year / all-time ranges
- ✅ collection summary and average plays/week
- ✅ monthly current-year chart
- ✅ all-time yearly chart
- ✅ genre listening breakdown
- ✅ first vinyl
- ✅ most-played rankings

## Discogs — active

1. ✅ **VinylApp-106 — Discogs account connection + API foundation**
   - OAuth signing, secure credential storage, identity/API boundaries, providers
   - Settings connection UI, browser authorization, callback/deep link, connected username, disconnect
2. ✅ **VinylApp-090 — Discogs search + Add Record autofill**
   - vinyl title/artist search and exact pressing selection
   - year, label, genres/styles, artwork autofill
   - preserved Discogs release identity
3. ✅ **VinylApp-107 — Import Discogs collection**
   - paginated connected-account collection import
   - vinyl-only filtering plus exact-ID duplicate detection
   - possible local duplicate review before writes
   - progress + partial failure/warning summaries
4. ✅ **VinylApp-105 — Track schema + Discogs tracklist import**
   - schema v5 Tracks + transactional repository replacement
   - Discogs positions/sides/durations mapped into local tracklists
   - Add Record + collection import persistence and Album Detail display
   - verifier/live device validation completed
5. ✅ **VinylApp-114 — Engineering audit hardening**
   - schema v6 cascade/index reliability migration
   - atomic multi-repository record writes and canonical deletion
   - Discogs transport/artwork hardening + release-build CI check (not published)
6. 🚧 **VinylApp-091 — Barcode → exact Discogs release**

## NFC

Persistence exists; device flows remain:

- ⬜ Android NFC permissions/setup
- ⬜ write NFC tag flow
- ⬜ foreground scan → auto log play

## Discover / recommendations

- ⬜ Discover production screen
- ⬜ recommendation service using genres, artists, play history, recency, and future metadata
- ⬜ explainable recommendations (“because you play…”, “similar genre…”, etc.)
- ⬜ rediscovery insights / not-played-recently suggestions
- ⬜ Album Wrapped / yearly listening story

## Release polish

- 🚧 Groovefolio branding/documentation refresh (`VinylApp-108`)
- ⬜ final logo/app icon/adaptive icon
- ⬜ splash/bootstrap flow
- ⬜ loading/error/empty-state hardening
- ⬜ accessibility semantics
- ⬜ Play Store account/signing/listing/release process

## Product principles

- core collection remains usable without an account
- SQLite/local data is the source of truth for the user's collection
- external services enhance rather than own the experience
- repositories own persistence details
- services own multi-repository/business workflows
- UI consumes typed providers/models rather than raw Drift or external JSON
