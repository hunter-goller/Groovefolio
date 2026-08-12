# Dependency Graph

## Allowed direction

```mermaid
flowchart TD
    Screens[Screens]
    FeatureWidgets[Feature widgets]
    SharedWidgets[Shared widgets]
    FeatureProviders[Feature providers]
    DependencyProviders[Repository and service providers]
    Services[Services]
    Repositories[Repositories]
    Database[Drift database]
    Platform[Device or external adapters]

    Screens --> FeatureWidgets
    Screens --> SharedWidgets
    Screens --> FeatureProviders
    FeatureWidgets --> FeatureProviders
    FeatureProviders --> DependencyProviders
    FeatureProviders --> Services
    FeatureProviders --> Repositories
    DependencyProviders --> Services
    DependencyProviders --> Repositories
    Services --> Repositories
    Services --> Platform
    Repositories --> Database
```

## Rules

- Screens may depend on providers, routing, and widgets.
- Widgets expose data and callbacks; they do not construct repositories.
- Providers expose repositories, services, and asynchronous feature state.
- Services coordinate multi-step workflows.
- Repositories own Drift queries.
- Drift code must not import feature UI.
- Shared layers must not depend on one feature's presentation code.

## Current graph through VinylApp-017

```mermaid
flowchart TD
    Main[main.dart]
    RouterProvider[routerProvider]
    DatabaseProvider[databaseProvider]
    AlbumRepoProvider[albumRepositoryProvider]
    ArtistRepoProvider[artistRepositoryProvider]
    PlayRepoProvider[playRepositoryProvider]
    NfcRepoProvider[nfcTagRepositoryProvider]
    RepositoryProviders[repository_providers.dart import surface]
    PlayLoggingProvider[playLoggingServiceProvider]
    PlayLoggingService[PlayLoggingService]
    Router[GoRouter]
    Placeholders[Placeholder screens]
    AlbumRepo[AlbumRepository]
    ArtistRepo[ArtistRepository]
    PlayRepo[PlayRepository]
    NfcRepo[NfcTagRepository]
    Database[AppDatabase]
    Tables[Artists + Albums + Plays + NfcTags]

    Main --> RouterProvider
    Main --> DatabaseProvider
    RouterProvider --> Router
    Router --> Placeholders
    AlbumRepoProvider --> DatabaseProvider
    AlbumRepoProvider --> AlbumRepo
    ArtistRepoProvider --> DatabaseProvider
    ArtistRepoProvider --> ArtistRepo
    PlayRepoProvider --> DatabaseProvider
    PlayRepoProvider --> PlayRepo
    NfcRepoProvider --> DatabaseProvider
    NfcRepoProvider --> NfcRepo
    RepositoryProviders --> AlbumRepoProvider
    RepositoryProviders --> ArtistRepoProvider
    RepositoryProviders --> PlayRepoProvider
    RepositoryProviders --> NfcRepoProvider
    PlayLoggingProvider --> AlbumRepoProvider
    PlayLoggingProvider --> PlayRepoProvider
    PlayLoggingProvider --> PlayLoggingService
    PlayLoggingService --> AlbumRepo
    PlayLoggingService --> PlayRepo
    AlbumRepo --> Database
    ArtistRepo --> Database
    PlayRepo --> Database
    NfcRepo --> Database
    DatabaseProvider --> Database
    Database --> Tables
```

The Album, Artist, Play, and NFC-tag repository boundaries now exist.
VinylApp-016 provides a single import surface plus override coverage.
VinylApp-017 adds PlayLoggingService and its provider; feature providers remain
planned and no feature screen consumes repository/service state yet.

## Collection ticket dependency graph

```mermaid
flowchart TD
    T11[VinylApp-011 Plays ✅]
    T12[VinylApp-012 Migration ✅]
    T13[VinylApp-013 AlbumRepository ✅]
    T14[VinylApp-014 ArtistRepository ✅]
    T15[VinylApp-015 PlayRepository ✅]
    T40[VinylApp-040 NFC schema / v2 ✅]
    T41[VinylApp-041 NfcTagRepository ✅]
    T16[VinylApp-016 Repository providers ✅]
    T17[VinylApp-017 PlayLoggingService ✅]
    T43[VinylApp-043 Feature providers]
    T08[VinylApp-008 Theme]
    T18[VinylApp-018 Collection]

    T11 --> T12
    T12 --> T13
    T12 --> T14
    T12 --> T15
    T13 --> T16
    T14 --> T16
    T15 --> T16
    T40 --> T41
    T41 --> T16
    T16 --> T17
    T17 --> T43
    T43 --> T18
    T08 --> T18
```

VinylApp-017 now unlocks the actual play-logging workflow. VinylApp-043 is the
direct task that provides the state named in VinylApp-018.

## Prototype exception

The unmerged VinylApp-018 branch skips this graph by using fake data and local
state. That makes it a visual prototype, not the final Collection architecture.
