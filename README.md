# Groovefolio

[![CI](https://github.com/hunter-goller/Groovefolio/actions/workflows/ci.yml/badge.svg)](https://github.com/hunter-goller/Groovefolio/actions/workflows/ci.yml)

Groovefolio is an Android-first, local-first Flutter app for collecting vinyl and tracking listening. Records, artwork, plays, statistics, recommendations, and NFC associations live on the device. A Groovefolio account is not required. Discogs connection, release lookup, barcode search, and collection import are optional.

The app has not had a public Play Store release. The Android application ID is `app.groovefolio`; the Dart package and historical task IDs retain `vinyl_app` and `VinylApp-###`.

## What works on `main`

- Browse, search, filter, add, edit, delete, and import records, with local artwork, genres, and Discogs tracklists.
- Log plays manually; link NFC tags to records and log full-album plays from Android tag taps. NFC hardware behavior still needs final device validation.
- View current-year and all-time statistics and local, explainable suggestions for records already owned.
- Connect Discogs through OAuth, search exact releases or barcodes, and review collection imports before writing local records.
- Replay the interactive first-run walkthrough from Settings.

See [implementation status](docs/implementation-status.md) for the current baseline and [roadmap](ROADMAP.md) for remaining release work.

## Develop

Requires Flutter with a Dart SDK compatible with [`pubspec.yaml`](pubspec.yaml), Android tooling for device builds, and PowerShell for the repository verifier.

```powershell
git clone https://github.com/hunter-goller/Groovefolio.git
cd Groovefolio
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
.\tools\verify_vinylapp_012.ps1
```

See [development setup](docs/development/setup.md) for Discogs development configuration, [testing](docs/development/testing.md), and [Android upload signing](docs/development/android-release-signing.md). Keep real Discogs secrets and signing credentials outside the repository. The current client embeds development Discogs app credentials at build time; the production credential strategy remains open before public distribution.

## Documentation

Start at the [documentation index](docs/README.md). It separates living guidance from [historical ticket notes](docs/archive/README.md). Source of truth for current routes and schema is [`AppRoutes`](lib/routing/app_routes.dart) and [`SchemaVersions`](lib/db/migrations/schema_versions.dart).