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

## Discogs app credentials

Do not place real Discogs credentials in source files or commit them.

```powershell
flutter run `
  --dart-define=DISCOGS_CONSUMER_KEY=YOUR_KEY `
  --dart-define=DISCOGS_CONSUMER_SECRET=YOUR_SECRET
```

The app can build/test without real values. Live OAuth requests require a registered Discogs application configured to return to `groovefolio://discogs-auth`. Android and iOS register that custom URI scheme.

## Technical identifiers

The product/repository is Groovefolio, while these remain intentionally unchanged:
- Dart package `vinyl_app`
- Android application ID `com.huntergoller.vinyl_app`
- SQLite file `vinyl_app_db.sqlite`
