# Vinyl App 🎵

[![CI](https://github.com/hunter-goller/vinyl-app/actions/workflows/ci.yml/badge.svg)](https://github.com/hunter-goller/vinyl-app/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Status](https://img.shields.io/badge/status-pre--alpha-orange)

Vinyl App is a local-first Flutter application for vinyl collectors. It is being
designed to combine collection management, listening history, personal
analytics, music discovery, and NFC-assisted play logging in one experience.

Most collection tools focus on **what you own**. Vinyl App is intended to also
show **how your records fit into your life**: what you return to, what you have
forgotten, how your listening changes over time, and which records matter most
to you.

> **Project status:** Pre-alpha. The core Drift schema, v1 migration workflow,
> AlbumRepository, and ArtistRepository are implemented. All user-facing screens are
> still placeholders. VinylApp-018 contains an unmerged Collection UI prototype that
> uses fake data and local state; it is not part of the current application.

## Current progress

| Area | Status |
| --- | --- |
| Flutter project and repository structure | Complete |
| Strict analysis and formatting rules | Complete |
| GitHub Actions CI | Complete |
| GoRouter navigation | Complete |
| Riverpod foundation | Complete |
| Drift/SQLite connection | Complete |
| Artists table | Complete — VinylApp-010 |
| Albums table and artist foreign key | Complete — VinylApp-009 |
| Plays table and side tracking | Complete — VinylApp-011 |
| v1 migration and Drift schema snapshot | Complete — VinylApp-012 |
| AlbumRepository + provider | Complete — VinylApp-013 |
| ArtistRepository + provider | Complete — VinylApp-014 |
| PlayRepository | Next — VinylApp-015 |
| Remaining repository providers | Planned — VinylApp-016 |
| PlayLoggingService | Planned — VinylApp-017 |
| Feature-level collection providers | Planned — VinylApp-043 |
| Theme and design tokens | Deferred — VinylApp-008 |
| Collection screen | On hold — VinylApp-018 |
| Shared Collection widgets | Unmerged prototype work; not present on `main` |

See the [implementation status](docs/implementation-status.md) and
[roadmap](ROADMAP.md) for the exact dependency order.

## Product vision

### Collection management

- Add, edit, search, filter, and remove records.
- Store release, label, artwork, purchase, and condition information.
- Open detailed album pages from the collection.
- Optionally enrich records through a future Discogs integration.

### Listening history

- Log a full album, Side A, or Side B.
- Browse play history by album and across the full collection.
- Use NFC tags as a fast path for logging a record.

### Statistics and discovery

- Track most-played albums, artists, genres, and listening periods.
- Surface records that have not been played recently.
- Generate recommendations from collection metadata and listening history.

### Album Wrapped

Album Wrapped is the planned signature feature. Each record will have a
personal listening story containing insights such as first and latest play,
total plays, streaks, time-of-day or seasonal patterns, side preference,
collection ranking, rediscovery moments, and related recommendations.

## Technology stack

| Concern | Technology |
| --- | --- |
| Application framework | Flutter and Dart |
| Navigation | `go_router` |
| State and dependency management | Riverpod with code generation |
| Local persistence | Drift over SQLite |
| Code generation | `build_runner`, Riverpod Generator, Drift Dev |
| Quality checks | Flutter analyzer, formatter, tests |
| Continuous integration | GitHub Actions |

The intended release target is Android through Google Play. Flutter platform
scaffolding is present for other platforms, but those targets are not currently
planned releases.

## Architecture

### Current data-layer flow

```mermaid
flowchart TD
    M[main.dart]
    PS[ProviderScope]
    RP[routerProvider]
    DP[databaseProvider]
    ARP[albumRepositoryProvider]
    AIP[artistRepositoryProvider]
    GR[GoRouter]
    Screens[Placeholder screens]
    AR[AlbumRepository]
    AIR[ArtistRepository]
    DB[AppDatabase]
    Artists[Artists]
    Albums[Albums]
    Plays[Plays]
    SQLite[(SQLite)]

    M --> PS
    PS --> RP
    PS --> DP
    RP --> GR
    GR --> Screens
    ARP --> DP
    ARP --> AR
    AIP --> DP
    AIP --> AIR
    AR --> DB
    AIR --> DB
    DP --> DB
    DB --> Artists
    DB --> Albums
    DB --> Plays
    DB --> SQLite
```

### Target feature flow

```mermaid
flowchart TD
    UI[Flutter screen or widget]
    FP[Feature provider]
    SP[Repository/service providers]
    S[Service when orchestration is needed]
    R[Repository]
    D[Drift]
    Q[(SQLite)]

    UI --> FP
    FP --> SP
    FP --> S
    FP --> R
    S --> R
    SP --> R
    R --> D
    D --> Q
```

`AlbumRepository` and `ArtistRepository` are implemented. PlayRepository,
services, and feature providers such as `albumsProvider` and
`collectionFiltersProvider` are still planned.

Read the [architecture overview](docs/architecture/overview.md).

## Repository layout

```text
vinyl-app/
├── .github/                 # CI workflow and pull-request template
├── docs/                    # Technical and product documentation
├── design/                  # Visual assets and future diagrams
├── drift_schemas/           # Versioned Drift schema snapshots
├── lib/
│   ├── db/                  # Drift DB, migrations, Artists/Albums/Plays schema
│   ├── features/            # Placeholder route-level screens
│   ├── providers/           # Future shared feature providers
│   ├── repositories/        # AlbumRepository + ArtistRepository
│   ├── routing/             # Route constants and GoRouter provider
│   ├── services/            # Future business workflows
│   ├── theme/               # Empty scaffold; VinylApp-008 deferred
│   ├── types/               # Shared persistence/domain enums such as SidePlayed
│   ├── utils/               # Empty scaffold
│   ├── widgets/             # Empty scaffold on main
│   └── main.dart            # ProviderScope and app composition root
├── test/                    # Database, migration, repository, routing, smoke tests
├── CHANGELOG.md
├── ROADMAP.md
└── README.md
```

The widgets created on the VinylApp-018 prototype branch are not present in this
layout because that branch was not merged.

## Routes

| Path | Current screen |
| --- | --- |
| `/` | Collection placeholder |
| `/stats` | Statistics placeholder |
| `/discover` | Discover placeholder |
| `/album/new` | Add Record placeholder |
| `/album/:id` | Album Detail placeholder with path parameter |
| `/play/log` | Log Play placeholder |

The routes resolve so navigation and path-parameter handling can be verified.
External Android App Links are not configured.

## Local development

### Prerequisites

- Flutter on the stable channel
- A Dart SDK compatible with `^3.12.2`
- Android Studio or another supported Flutter development environment
- An Android emulator or physical device

### Setup

```bash
git clone https://github.com/hunter-goller/vinyl-app.git
cd vinyl-app
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter run
```

Generated `*.g.dart` files are intentionally ignored. Regenerate them whenever a
Drift schema or annotated Riverpod provider changes.

See the [development setup guide](docs/development/setup.md).

## Database migration workflow

The v1 schema contains Artists, Albums, and Plays. `AppDatabase` uses
`SchemaVersions.current`, and a fresh database is created through
`migrateToV1()`.

The committed schema snapshot lives at:

```text
drift_schemas/drift_schema_v1.json
```

When the Drift schema changes, regenerate code and export the appropriate schema
snapshot before merging.

## Continuous integration

Every pull request targeting `main`, every push to `main`, and manual workflow
runs execute:

1. Dependency installation
2. Drift and Riverpod code generation
3. Formatting verification
4. Static analysis
5. Automated tests
6. Drift schema-snapshot verification
7. Debug APK build verification

See [CI documentation](docs/architecture/ci-cd.md).

## Documentation

Start with the [documentation index](docs/README.md).

- [Current implementation status](docs/implementation-status.md)
- [Architecture overview](docs/architecture/overview.md)
- [Project structure](docs/architecture/project-structure.md)
- [Database](docs/architecture/database.md)
- [Repository pattern](docs/architecture/repository-pattern.md)
- [Routing](docs/architecture/routing.md)
- [State management](docs/architecture/state-management.md)
- [Testing](docs/development/testing.md)
- [Architecture decisions](docs/decisions/README.md)
- [Feature specifications](docs/features/README.md)
- [Roadmap](ROADMAP.md)
- [Changelog](CHANGELOG.md)

## Project ownership

Vinyl App is a personal application project being developed toward a polished
Google Play release. The repository documentation is primarily an engineering
record and product-development reference rather than an open-source contributor
guide.
