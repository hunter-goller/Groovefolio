# State management

Groovefolio uses Riverpod for dependency injection and reactive feature state.

## Repository providers
Repositories expose generated providers and are re-exported through `providers/repository_providers.dart` for a common dependency surface.

## Collection providers
`album_providers.dart` currently owns:
- collection filter/sort state
- collection album view models
- collection loading/search
- album detail composition
- recently played albums
- play counts
- album mutation controller

## Genre providers
`genre_providers.dart` exposes:
- all genres
- genres assigned to one album

## Stats
The Stats screen composes a `StatsDashboardData` FutureProvider around `StatsService` and artist lookup.

## Discogs
Part 1 exposes providers for:
- config
- secure credential store
- API client
- auth service
- connected account lookup

## Testing
Provider overrides are preferred over global singletons so repository/service behavior can be replaced with in-memory fakes in tests.
