# Groovefolio 🎵

[![CI](https://github.com/hunter-goller/Groovefolio/actions/workflows/ci.yml/badge.svg)](https://github.com/hunter-goller/Groovefolio/actions/workflows/ci.yml)

Groovefolio is a local-first Flutter app for vinyl collectors. It combines collection management, listening history, statistics, album artwork, genres, and a growing Discogs integration while keeping the core collection usable offline and without a required account.

The repository is now named **Groovefolio**. Historical Trello tickets still use the `VinylApp-###` prefix, and the internal Dart package remains `vinyl_app`; those identifiers are intentionally preserved for continuity.

## Current product state

Implemented on `main`:

- collection browsing with search, genre filtering, and Recent / A–Z / Most played sorting
- add, edit, view, and delete record flows
- local album artwork picking and persistent artwork storage
- many-to-many genres with reusable genre chips/input
- manual play logging with date, time, and full/side A/side B tracking
- album play history and play counts
- collection statistics for the current year and all time
- monthly and yearly play charts
- listening-by-genre breakdown and most-played albums
- local SQLite persistence through Drift with frozen v1 → v2 → v3 → v4 migrations
- NFC tag persistence/repository groundwork
- development reset/seed tooling with optional MusicBrainz/Cover Art Archive artwork lookup
- Discogs OAuth 1.0a account connection with browser authorization, deep-link callback, secure credential storage, identity lookup, typed failures, and Settings UI

Still in progress or planned:

- Discogs collection import (`VinylApp-107`)
- track schema/import (`VinylApp-105`)
- barcode lookup (`VinylApp-091`)
- NFC write/read flows
- Discover recommendations and explainable recommendation engine
- release branding, icons, splash, accessibility, and Play Store polish

## Stack

- Flutter / Dart
- Riverpod + riverpod_generator
- Drift / SQLite
- go_router
- GitHub Actions
- `image_picker` + local filesystem artwork storage
- `flutter_secure_storage` 10.3.1 for Discogs OAuth user credentials
- `crypto` for OAuth 1.0a HMAC-SHA1 signing
- `url_launcher` for Discogs browser authorization and attribution links
- `app_links` for the `groovefolio://discogs-auth` OAuth callback

## Architecture

Groovefolio keeps persistence, business rules, and UI separated:

```text
UI / screens / shared widgets
          ↓
Riverpod feature providers
          ↓
Services (business workflows)
          ↓
Repository interfaces
          ↓
Drift repositories
          ↓
SQLite
```

External integrations are isolated behind services/clients:

```text
UI
 ↓
DiscogsAuthService / DiscogsCatalogService
 ↓
DiscogsApiClient
 ↓
OAuth signing + HTTP
 ↓
Discogs
```

Screens and services do not construct Drift companions directly. Repositories own IDs, timestamps, and persistence objects.

## Database schema

Current schema version: **v4**.

```text
v1  Artists ──< Albums ──< Plays
v2                 └────  NfcTags (one tag per album)
v3                 └────< AlbumGenres >──── Genres
v4                 └────  AlbumDiscogsReleases (exact Discogs release link)
```

- `Artists`: canonical artist rows
- `Albums`: title, artist, year, label, artwork path, purchase metadata, created timestamp
- `Plays`: album, played timestamp, side played, created timestamp
- `NfcTags`: unique physical NFC tag ↔ unique album association
- `Genres`: case-insensitive unique genre names
- `AlbumGenres`: many-to-many album/genre join table
- `AlbumDiscogsReleases`: one-to-one local album ↔ exact Discogs release ID link

The v1/v2/v3/v4 migrations are intentionally frozen once shipped. New physical schema changes must create a new migration/version rather than rewriting history.

## Routes

| Route | Screen |
|---|---|
| `/` | Collection |
| `/stats` | Stats |
| `/discover` | Discover placeholder |
| `/album/new` | Add Record |
| `/album/:id` | Album Detail |
| `/album/:id/edit` | Edit Record |
| `/play/log` | Log Play |
| `/settings` | Settings / Discogs connection |

The Discogs OAuth callback uses the platform custom URI `groovefolio://discogs-auth`; it is handled by `app_links`, not as a public `go_router` page.

## Getting started

```powershell
git clone https://github.com/hunter-goller/Groovefolio.git
cd Groovefolio
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

For the full project verification workflow:

```powershell
.\tools\verify_vinylapp_012.ps1
```

The script formats Dart, regenerates code, runs the analyzer, runs tests, and exports the current Drift schema snapshot.

See [docs/development/setup.md](docs/development/setup.md) for environment details.

## Development seed

Normal debug seed:

```powershell
flutter run -t lib/dev/seed_main.dart
```

Destructive reset + artwork seed (default 10 albums):

```powershell
flutter run -t lib/dev/reset_seed_main.dart
```

Variable stress size:

```powershell
flutter run -t lib/dev/reset_seed_main.dart --dart-define=DEV_SEED_ALBUM_COUNT=60
```

The destructive reset deletes the current local development collection and referenced artwork before rebuilding seed data. See [docs/development/dev-seed.md](docs/development/dev-seed.md).

## Discogs development configuration

The Discogs integration reads application credentials from compile-time defines. Do **not** commit real credentials.

```powershell
flutter run `
  --dart-define=DISCOGS_CONSUMER_KEY=YOUR_KEY `
  --dart-define=DISCOGS_CONSUMER_SECRET=YOUR_SECRET
```

The OAuth callback URI is `groovefolio://discogs-auth`. Android and iOS register that custom scheme and the root app completes the OAuth verifier exchange when Discogs returns to Groovefolio.

User OAuth access credentials are stored with `flutter_secure_storage`. The application Consumer Key/Secret are development configuration for now; production secret handling must be revisited before public distribution.

See [docs/integrations/discogs.md](docs/integrations/discogs.md).

## Documentation

Start at [docs/README.md](docs/README.md). The documentation set is organized into architecture, development, features, integrations, decisions, and design assets.
