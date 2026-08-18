# Discogs integration

Discogs is an optional enhancement; Groovefolio's local collection remains usable without connecting an account.

## Roadmap split

### VinylApp-106 — account connection + shared API foundation
Implemented across Parts 1 and 2:
- `DiscogsConfig`
- OAuth 1.0a HMAC-SHA1 signer
- request-token exchange
- access-token exchange
- identity lookup
- typed auth/network/API/rate-limit failures
- secure credential store
- `DiscogsAuthService`
- Riverpod providers
- Settings integration
- Connect Discogs browser authorization
- `groovefolio://discogs-auth` platform callback via `app_links`
- verifier exchange and secure access-token persistence
- `Connected as <username>` identity UI
- disconnect and cancelled-authorization cleanup
- Discogs attribution/disclaimer UI

### VinylApp-090 — search/autofill
Implemented:
- search connected Discogs by artist/title
- show up to five release candidates with cover/year/label/country/format metadata
- fetch the exact selected release before autofill
- populate editable title, artist, year, label, genres/styles, and artwork
- persist downloaded artwork through `ArtworkStorageService`
- persist the exact Discogs release ID in schema v4 for future duplicate detection/import/barcode work
- surface typed empty/error/rate-limit states without breaking manual Add Record

### VinylApp-107 — collection import
Import a connected user's Discogs collection with pagination, duplicate classification, progress, and partial failure handling.

### VinylApp-105 / 091
Tracklist import and barcode → exact release build on the same client/foundation.

## Development credentials

The app-level Consumer Key/Secret are read from compile-time defines:

```powershell
flutter run `
  --dart-define=DISCOGS_CONSUMER_KEY=YOUR_KEY `
  --dart-define=DISCOGS_CONSUMER_SECRET=YOUR_SECRET
```

Never commit real values.

OAuth callback URI: `groovefolio://discogs-auth`. Android and iOS register the custom scheme, while `app_links` captures cold-start and warm-app callbacks.

The code can compile and unit-test with empty values; live API calls require valid application credentials.

## User credentials

After OAuth authorization, the user's access token + token secret are stored through `flutter_secure_storage` rather than SQLite or source control.

`flutter_secure_storage` is pinned to **10.3.1** on the current Android SDK 36 toolchain.

## Production security note

A Consumer Secret compiled into a distributed mobile application cannot be assumed to remain secret. Before Play Store release, review whether Groovefolio should use a backend/proxy or another production-safe credential strategy.
