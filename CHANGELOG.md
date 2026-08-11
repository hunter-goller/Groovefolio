# Changelog

All notable changes to Vinyl App are recorded in this file.

The project is pre-release, so current entries describe development milestones
rather than stable public versions. The format is based on Keep a Changelog.

## [Unreleased]

### Added

- Flutter application scaffold and cross-platform runner projects.
- Strict Dart analyzer and lint configuration.
- GitHub pull-request template and protected-branch workflow.
- GitHub Actions pipeline for code generation, formatting, analysis, tests,
  Drift schema verification, and debug APK build verification.
- Central route constants and a Riverpod-provided GoRouter instance.
- Placeholder routes for Collection, Statistics, Discover, Add Record, Album
  Detail, and Log Play.
- Riverpod `ProviderScope` at the application root.
- Long-lived Riverpod database provider with disposal handling.
- Drift database backed by a SQLite file in the application documents
  directory.
- Injectable `QueryExecutor` support for in-memory database tests.
- Artists table and generated `Artist` data class.
- Albums table and generated `Album` data class.
- Plays table with `SidePlayed` persistence for full record, Side A, and Side B.
- Enforced foreign-key relationships from albums to artists and plays to albums.
- Initial v1 Drift migration through `migrateToV1()`.
- Central `SchemaVersions` constants wired to `AppDatabase.schemaVersion`.
- Version-controlled `drift_schema_v1.json` schema snapshot.
- In-memory migration test proving empty database → v1 table creation and schema
  version.
- `IAlbumRepository` and Drift-backed `AlbumRepository` with `findAll()`,
  `findById()`, `create()`, `update()`, `delete()`, and `search(query)`.
- Case-insensitive album search across album title and artist name.
- `albumRepositoryProvider` for dependency injection through Riverpod.
- In-memory AlbumRepository tests covering CRUD and search behavior.
- `IArtistRepository` and Drift-backed `ArtistRepository` with `findOrCreate()`,
  `findById()`, and `findAll()`.
- Case-insensitive, idempotent artist deduplication with trimmed artist names.
- `artistRepositoryProvider` for Riverpod dependency injection.
- In-memory ArtistRepository tests covering creation, lookup, listing, and
  deduplication.
- `IPlayRepository` and Drift-backed `PlayRepository` with `create()`,
  `findByAlbum()`, `findAll()`, `deleteById()`, `getPlayCountByAlbum()`, and
  `getRecentlyPlayed(limit)`.
- `playRepositoryProvider` for Riverpod dependency injection.
- `INfcTagRepository` and Drift-backed `NfcTagRepository` with `create()`,
  `findByTagId()`, `findByAlbum()`, and `delete()`.
- `nfcTagRepositoryProvider` for Riverpod dependency injection.
- Central `repository_providers.dart` import surface for all four repository
  interfaces/providers.
- ProviderContainer override tests covering Album, Artist, Play, and NFC-tag
  repository dependencies.
- In-memory NfcTagRepository tests covering creation, tag lookup, album lookup,
  deletion, not-found behavior, and input validation.
- VinylApp-040 `NfcTags` table with unique NFC tag IDs and a unique Album foreign key, enforcing one registered tag per album.
- Schema version 2 with an explicit v1 → v2 NFC-table migration and upgrade test.
- In-memory PlayRepository tests covering persistence, per-album ordering,
  deletion, play counts, distinct recently played albums, limits, and
  `SidePlayed` enum round-trips.
- Database, table, router-provider, and application smoke tests.
- Phase 1 repository, architecture, feature, and development documentation.
- A current-implementation status page that distinguishes merged work from
  unmerged prototypes.

### Changed

- Migrated the project from an earlier React Native prototype to Flutter.
- Replaced the default Flutter counter example with a Riverpod and GoRouter app
  composition root.
- Deferred the custom theme until the data layer is stable and polished screen
  development begins.
- Used Drift's native `LazyDatabase` and
  `NativeDatabase.createInBackground` APIs instead of `drift_flutter`
  convenience helpers.
- Pinned `drift` and `drift_dev` to compatible `2.34.0` versions while the
  migration tooling is established.
- CI now verifies that the committed Drift schema snapshot matches the current
  database schema.
- Clarified that VinylApp-018 and its prototype widgets are not merged into
  `main` and do not count as completed functionality.
- Clarified that VinylApp-016 completes the repository-provider layer even
  though VinylApp-013 through VinylApp-015 introduce the Album, Artist, and Play
  repository providers.

- Repository creation APIs now keep generated IDs, timestamps, and Drift
  companion construction inside AlbumRepository and PlayRepository.
- Fresh databases create the current schema directly; the historical v1 helper
  remains an immutable v1 definition.

### Fixed

- Corrected album table tests to use Drift's generated `AlbumsCompanion` type.
- Preserved the `SidePlayed` import required by generated Drift database code.
- Removed obsolete `--delete-conflicting-outputs` examples from project
  documentation and workflow guidance.
- Corrected documentation that could otherwise imply the Collection prototype
  or shared widgets were already part of the application.
- Removed the stale PlayRepository performance TODO after `getRecentlyPlayed()`
  moved to SQL aggregation.
- Corrected startup documentation to reflect the production `LazyDatabase`
  connection behavior.

## Not included on `main`

The following are not changelog additions because they only exist on an
unmerged VinylApp-018 prototype branch:

- Collection UI backed by `fakeAlbums`
- `AlbumListTile`
- `BottomNavBar`
- `GenreChip`
- `SummaryBar`
- `EmptyState`
- `FilterChipRow`
- `PrimaryButton`
- `SectionHeader`

## Release history

No public releases have been published yet.
