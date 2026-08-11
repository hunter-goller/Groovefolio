# State Management and Dependency Injection

Vinyl App uses Riverpod for state management and dependency injection.

## Root scope

`main()` wraps the app with `ProviderScope`:

```dart
runApp(const ProviderScope(child: MyApp()));
```

## Providers implemented today

### `routerProvider`

Generated from the annotated `router()` function. It owns the `GoRouter`
instance used by `MaterialApp.router`.

### `databaseProvider`

Generated from an annotated `database()` function with `keepAlive: true`. The
database is a process-wide dependency and registers `db.close` through
`ref.onDispose`.

### `albumRepositoryProvider`

Generated from the annotated `albumRepository()` function introduced by
VinylApp-013. It watches `databaseProvider`, constructs `AlbumRepository`, and
exposes it as `IAlbumRepository`.

### `artistRepositoryProvider`

Generated from the annotated `artistRepository()` function introduced by
VinylApp-014. It watches `databaseProvider`, constructs `ArtistRepository`, and
exposes it as `IArtistRepository`.

### `playRepositoryProvider`

Generated from the annotated `playRepository()` function introduced by
VinylApp-015. It watches `databaseProvider`, constructs `PlayRepository`, and
exposes it as `IPlayRepository`.

### `nfcTagRepositoryProvider`

Generated from the annotated `nfcTagRepository()` function introduced by the
VinylApp-041 change set. It watches `databaseProvider`, constructs
`NfcTagRepository`, and exposes it as `INfcTagRepository`.

No service or feature-state providers are implemented yet.

## Repository-provider roadmap — VinylApp-016

VinylApp-016 completes and standardizes the repository provider layer. All four
repository providers are introduced by their repository tickets:

- `albumRepositoryProvider`
- `artistRepositoryProvider`
- `playRepositoryProvider`
- `nfcTagRepositoryProvider`

VinylApp-016 should not duplicate them; it standardizes naming/lifetimes and adds
provider-override coverage.

Repository providers must remain overrideable in tests. UI and feature providers
should not read Drift directly.

## Planned feature providers — VinylApp-043

- `albumsProvider`
- `albumProvider(id)`
- `recentlyPlayedProvider`
- `playCountProvider(albumId)`
- `collectionFiltersProvider`

VinylApp-043 is the direct provider dependency identified by VinylApp-018.

## Collection state flow

```mermaid
flowchart TD
    CS[CollectionScreen]
    AP[albumsProvider]
    CFP[collectionFiltersProvider]
    ARP[albumRepositoryProvider]
    PRP[playRepositoryProvider]
    AR[AlbumRepository]
    PR[PlayRepository]
    DB[AppDatabase]

    CS --> AP
    CS --> CFP
    AP --> CFP
    AP --> ARP
    AP --> PRP
    ARP --> AR
    PRP --> PR
    AR --> DB
    PR --> DB
```

The exact implementation may evolve, but the screen must consume provider state
rather than `fakeAlbums` or local-only sorting.

## Provider lifetime guidance

- Use a normal generated provider for cheap, recreatable dependencies.
- Use `keepAlive: true` for resources that must persist for the application
  lifetime, such as the database connection.
- Prefer auto-disposal for screen-specific asynchronous state when leaving the
  screen should release it.
- Document providers whose lifetimes differ from the default.

## Test overrides

Providers should be overrideable through `ProviderContainer` or
`ProviderScope(overrides: ...)`.

```dart
final container = ProviderContainer(
  overrides: [routerProvider.overrideWithValue(testRouter)],
);
```

Future repository and service providers must preserve this capability.

## Rules

1. UI watches providers; it does not instantiate repositories.
2. Providers do not contain Flutter widget code.
3. Providers do not query Drift directly when a repository owns that data.
4. A provider may call a repository directly for simple operations.
5. Multi-step workflows belong in services.
6. Provider errors should be represented explicitly.
7. Dependencies should be overrideable for tests.
8. Generated provider files are not edited or committed.
