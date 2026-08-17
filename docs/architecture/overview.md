# Architecture overview

Groovefolio is a local-first Flutter application. SQLite is the primary store for the user's collection and listening history; external integrations enhance that local experience.

## Layers

```text
Screens / widgets
      ↓
Feature providers / controllers
      ↓
Services (business workflows)
      ↓
Repository interfaces
      ↓
Drift repository implementations
      ↓
AppDatabase / SQLite
```

External API path:

```text
UI / future feature service
      ↓
DiscogsAuthService / future DiscogsService
      ↓
DiscogsApiClient
      ↓
OAuth signer + HTTP
      ↓
Discogs API
```

## Boundary rules

- Widgets do not construct Drift companions.
- Repositories own IDs, timestamps, queries, and Drift persistence objects.
- Services coordinate business rules that span repositories/filesystem/external APIs.
- Riverpod providers expose dependencies and feature state to UI.
- SQLite remains usable when Discogs is disconnected.
- External JSON is mapped into typed integration models before UI consumes it.

## Current service examples

- `PlayLoggingService`: validates an album and writes a play.
- `StatsService`: computes collection/listening aggregates from repositories.
- `ArtworkStorageService`: owns persisted artwork filesystem paths.
- `AlbumDeletionService`: coordinates plays, NFC association, artwork, and album deletion.
- `DiscogsAuthService`: owns the OAuth authorization lifecycle above `DiscogsApiClient`.

## Why local-first

Collection browsing, editing, play logging, and stats should not depend on a network account. This also gives future recommendation logic a stable local history to work from.
