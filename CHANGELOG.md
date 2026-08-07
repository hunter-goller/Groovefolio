# Changelog

All notable changes to Vinyl App are recorded in this file.

The project is pre-release, so current entries describe development milestones
rather than stable public versions. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Flutter application scaffold and cross-platform runner projects.
- Strict Dart analyzer and lint configuration.
- GitHub pull-request template and protected-branch workflow.
- GitHub Actions pipeline for code generation, formatting, analysis, tests, and
  debug APK build verification.
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
- Enforced foreign-key relationship from albums to artists.
- Database, table, router-provider, and application smoke tests.
- Phase 1 repository, architecture, feature, and development documentation.
- A current-implementation status page that distinguishes `main` from
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
- Clarified that VinylApp-018 and its prototype widgets are not merged into
  `main` and do not count as completed functionality.
- Documented VinylApp-043 as the task that will create `albumsProvider` and
  `collectionFiltersProvider`.

### Fixed

- Corrected album table tests to use Drift's generated
  `AlbumsCompanion` type.
- Corrected documentation that could otherwise imply the Collection prototype
  or shared widgets were already part of the application.

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
