# Discogs integration

Discogs is an optional enhancement; Groovefolio's local collection remains usable without connecting an account.

## Roadmap split

### VinylApp-106 — account connection + shared API foundation
**Part 1 merged:**
- `DiscogsConfig`
- OAuth 1.0a HMAC-SHA1 signer
- request-token exchange
- access-token exchange
- identity lookup
- typed auth/network/API/rate-limit failures
- secure credential store
- `DiscogsAuthService`
- Riverpod providers

**Part 2 next:**
- Settings integration
- Connect Discogs button
- external browser authorization
- app callback/deep link
- complete token exchange
- show connected username
- disconnect
- attribution/disclaimer UI

### VinylApp-090 — search/autofill
Search title + artist, show release choices, then autofill year, label, genres/styles, and artwork. The user chooses the release rather than Groovefolio silently guessing a pressing.

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

Current OAuth callback URI: `groovefolio://discogs-auth`. Part 2 will register/handle this deep link on Android.

The merged Part-1 code can compile and unit-test with empty values; live API calls require valid application credentials.

## User credentials

After OAuth authorization, the user's access token + token secret are stored through `flutter_secure_storage` rather than SQLite or source control.

`flutter_secure_storage` is pinned to **10.3.1** on the current Android SDK 36 toolchain.

## Production security note

A Consumer Secret compiled into a distributed mobile application cannot be assumed to remain secret. Before Play Store release, review whether Groovefolio should use a backend/proxy or another production-safe credential strategy.
