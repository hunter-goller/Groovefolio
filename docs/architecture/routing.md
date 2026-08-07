# Routing

Vinyl App uses `go_router`, with the router exposed through a generated Riverpod
provider.

## Files

- `lib/routing/app_routes.dart` — route path constants and path builders.
- `lib/routing/router.dart` — `GoRouter` construction and screen mapping.

## Route table

| Constant | Path | Screen | Status |
| --- | --- | --- | --- |
| `AppRoutes.collection` | `/` | `CollectionScreen` | Placeholder |
| `AppRoutes.stats` | `/stats` | `StatsScreen` | Placeholder |
| `AppRoutes.discover` | `/discover` | `DiscoverScreen` | Placeholder |
| `AppRoutes.addAlbum` | `/album/new` | `AddRecordScreen` | Placeholder |
| `AppRoutes.albumDetail` | `/album/:id` | `AlbumDetailScreen` | Placeholder with ID display |
| `AppRoutes.logPlay` | `/play/log` | `LogPlayScreen` | Placeholder |

## Router provider

`router.dart` uses Riverpod code generation:

```dart
@riverpod
GoRouter router(Ref ref) {
  return GoRouter(...);
}
```

This produces `routerProvider`, which is watched by `MyApp` and passed to
`MaterialApp.router`.

## Path construction

Navigation code should use constants and helpers:

```dart
context.go(AppRoutes.stats);
context.go(AppRoutes.albumDetailPath(albumId));
```

Do not write `'/stats'` or `'/album/$id'` throughout the UI.

## Album path parameter

The route `/album/:id` reads the parameter from `GoRouterState` and passes it to
`AlbumDetailScreen`:

```dart
final albumId = state.pathParameters['id']!;
return AlbumDetailScreen(albumId: albumId);
```

The real screen will use that ID to request the album through a provider and
repository.

## Deep-link scope

The route matcher accepts an in-app location such as `/album/test-123`. This is
the current meaning of deep-link-ready routing in the repository.

External links such as `https://example.com/album/test-123` require additional
platform configuration:

- Android intent filters and verified App Links
- A production domain and Android Digital Asset Links configuration

Those items are not implemented yet and should not be considered complete.

## Planned navigation shell

Collection, Statistics, and Discover are intended to become primary tabs. A
future shell route can preserve tab stacks and keep bottom navigation visible.
Add Record, Album Detail, and Log Play should sit outside or above the tab shell
as task/detail routes.

## Tests

Current routing tests verify that:

- `routerProvider` returns a configured `GoRouter`.
- The provider can be overridden in a `ProviderContainer`.
- The application boots into the Collection screen.

Future tests should directly resolve every route and verify the album ID
parameter.
