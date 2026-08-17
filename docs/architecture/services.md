# Services

Services hold workflows/business rules that are broader than one repository.

## PlayLoggingService
Validates the target album and creates a play through `IPlayRepository`.

## StatsService
Computes:
- collection summary
- plays/week
- most-played albums
- monthly current-year series
- yearly all-time series
- genre breakdown
- first vinyl
- album-level play statistics

## ArtworkStorageService
Owns persisted artwork under the app documents directory. The Albums table stores only the returned path.

## AlbumDeletionService
Coordinates deletion of:
- play rows
- linked NFC association
- artwork file
- album row

Album/genre join rows are removed by database cascade.

## DiscogsAuthService / DiscogsApiClient
Part 1 provides OAuth 1.0a request/access-token exchange, identity lookup, secure user credential storage, typed failures, and injectable providers. UI callback wiring remains Part 2.
