# Services

Services coordinate workflows that cross repositories, files, or external APIs. Repositories own persistence details.

- `PlayLoggingService`: validates the target album and records a play.
- `StatsService`: calculates collection and listening aggregates.
- `RecommendationService`: creates local, explainable suggestions for records already owned.
- `RecordWriteService`: coordinates add/edit/import writes in a database transaction.
- `ArtworkStorageService`: persists artwork in app storage.
- `AlbumDeletionService`: deletes an album and its database associations; artwork cleanup follows the database commit.
- `NfcService` and NFC play services: manage tag association, intent validation, automatic play, and duplicate protection.
- `DiscogsAuthService`, `DiscogsCatalogService`, and `DiscogsCollectionImportService`: optional OAuth, catalog, and import workflows over `DiscogsApiClient`.

The current mobile client communicates with Discogs directly. Backend proposals in another repository are not part of this app's `main` implementation.