# Development setup

## Clone

```powershell
git clone https://github.com/hunter-goller/Groovefolio.git
cd Groovefolio
```

## Flutter
Use the Flutter/Dart versions compatible with the repository's `pubspec.yaml` (`sdk: ^3.12.2` at this checkpoint).

```powershell
flutter doctor
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Run

```powershell
flutter run
```

Android is the primary development target. A physical Android device is supported and recommended for later NFC testing.

## Verify

```powershell
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
```

## Discogs backend connection

Do not place real Discogs credentials in source files or commit them.

```powershell
flutter run
```

The app uses `https://api.groovefolio.app` by default. No Discogs consumer credentials are required to build or run it. The backend handles the HTTPS OAuth callback; after authorizing, the callback page attempts to reopen the app and provides an **Open Groovefolio** fallback. Returning to the waiting Settings screen checks the connection automatically; **Check connection** remains available for retry.

## Technical identifiers

The product/repository is Groovefolio, while these remain intentionally unchanged:
- Dart package `vinyl_app`
- Android application ID `app.groovefolio`
- SQLite file `vinyl_app_db.sqlite`

Android builds created before the permanent application ID was selected used
`com.huntergoller.vinyl_app`. Android treats `app.groovefolio` as a separate
application, so those development installs are not upgraded and their local
collection is not migrated. This is intentional before the first public release.

Discogs now uses the Groovefolio backend without consumer-key defines. See [connection and device tests](../integrations/discogs.md).
