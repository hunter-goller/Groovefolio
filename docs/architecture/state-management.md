# State management

Riverpod gives screens a named way to obtain dependencies and state. A provider can supply a repository, an asynchronous result, or a controller that changes state. `ref.watch` subscribes to provider changes; `ref.read` obtains the current value without subscribing. Start with the [developer guide's refresh workflow](../developer-guide.md#provider-refreshes) when a screen shows old data after a successful save.

## Owners and lifetimes

| Area | Owner | What to remember |
|---|---|---|
| Database | `lib/db/database_provider.dart` and `AppDatabase` | Kept alive for the app container; closes when that container is disposed. |
| Repositories | Generated providers, re-exported by `lib/providers/repository_providers.dart` | Depend on the shared database. Overriding them is the usual test seam. |
| Collection filters and albums | `lib/providers/album_providers.dart` | Filter/sort state and asynchronous collection/detail/recent-play/count snapshots. Genre filtering also happens in the Collection screen. |
| Genres and tracks | Providers under `lib/providers/` | Related rows must be refreshed when their associations change. |
| Stats | `statsDashboardProvider` in the Stats screen | A family keyed by selected range; composes repository reads and `StatsService`. |
| Discover | `discoverRecommendationsProvider` in `lib/services/recommendation_service.dart` | Builds local recommendations from stored records and plays. |
| Discogs | `lib/services/discogs/discogs_providers.dart` | Owns config, credentials, clients, authorization state, and account lookup. Account lookup can make a live HTTP request. |
| Incoming NFC links | `incomingUriEventsProvider` in `lib/services/discogs/discogs_providers.dart` | Events are deliveries, not merely distinct URI values: the same URI can arrive again. |
| Walkthrough | `WalkthroughController` and `OnboardingService` | Only progress/completion is persisted; the selected walkthrough album and practice state are session-local. |
| Appearance | `lib/theme/theme_provider.dart` | Updates UI optimistically and serializes secure-storage writes; persistence failure can leave the current session showing the new choice. |

## A provider subscription is not a database subscription

Most data providers perform one-time repository `.get()` reads. Watching a repository provider subscribes to that dependency's identity, not to every row it changes. After a write, the caller must invalidate affected cached results so listening widgets read again.

For a provider family, `ref.invalidate(albumDetailProvider(albumId))` refreshes one album's cached entry. Invalidating the family refreshes all its existing entries. Choose the scope from the affected data. Auto-disposal can eventually discard an unused result, but navigation or disposal is not a reliable substitute for refresh after mutation.

Existing callers do not all invalidate the same providers. For example, manual play logging, automatic NFC logging, and import have different refresh lists. `AlbumMutations` is a convenience for core album writes; it does not own every multi-table workflow or every dependent view. Trace the actual caller before copying its refresh list. An import error can follow earlier committed records; the import screen refreshes collection/genre reads in its `finally` path so both success and failure expose committed records.

## Loading, errors, and durable saves

Handle loading, empty, missing-record, and failed-load states separately. A null record means it was not found; a thrown database or network error is a different condition. After an `await`, check widget lifetime before navigation or context-dependent feedback.

A service write and a UI refresh are separate steps. Do not report an already committed record as unsaved just because optional artwork, navigation, or feedback failed. See [write ordering and failure boundaries](../developer-guide.md#7-key-workflows).

## Testing changes

Override providers with controlled repositories/services for widget tests. Keep a consumer mounted while performing a mutation to verify that it actually refreshes: reading a new provider in a fresh container can hide a stale-cache bug. Use a real in-memory SQLite database when proving transaction rollback or SQL behavior; fake repositories alone cannot prove those properties.

See the [source/test map](../developer-guide.md#feature-to-code-map), [testing guide](../development/testing.md), and [code-generation instructions](../development/code-generation.md).
