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

1. 🚧 **VinylApp-106 — Discogs account connection + API foundation**
   - Part 1 merged: OAuth signing, secure credential storage, identity/API boundaries, providers
   - Part 2 next: Settings connection UI, browser authorization, callback/deep link, connected username, disconnect
2. ⬜ **VinylApp-090 — Discogs search + Add Record autofill**
   - title/artist search
   - top release matches
   - year, label, genres/styles, artwork autofill
   - preserve Discogs release identity
3. ⬜ **VinylApp-107 — Import Discogs collection**
   - paginated collection import
   - duplicate classification/review
   - progress + partial failure handling
4. ⬜ **VinylApp-105 — Track schema + Discogs tracklist import**
5. ⬜ **VinylApp-091 — Barcode → exact Discogs release**

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
