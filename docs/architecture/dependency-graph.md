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

## Current `main` graph

```mermaid
flowchart TD
    Main[main.dart]
    RouterProvider[routerProvider]
    DatabaseProvider[databaseProvider]
    Router[GoRouter]
    Placeholders[Placeholder screens]
    Database[AppDatabase]
    Tables[Artists and Albums]

    Main --> RouterProvider
    Main --> DatabaseProvider
    RouterProvider --> Router
    Router --> Placeholders
    DatabaseProvider --> Database
    Database --> Tables
```

Repositories, services, and feature providers are not implemented today.

## Collection ticket dependency graph

```mermaid
flowchart TD
    T11[VinylApp-011 Plays]
    T12[VinylApp-012 Migration]
    T13[VinylApp-013 AlbumRepository]
    T14[VinylApp-014 ArtistRepository]
    T15[VinylApp-015 PlayRepository]
    T16[VinylApp-016 Repository providers]
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
    T16 --> T43
    T43 --> T18
    T08 --> T18
```

VinylApp-017 is part of the core data-layer sequence and unlocks actual play
logging. VinylApp-043 is the direct task that provides the state named in
VinylApp-018.

## Prototype exception

The unmerged VinylApp-018 branch skips this graph by using fake data and local
state. That makes it a visual prototype, not the final Collection architecture.
