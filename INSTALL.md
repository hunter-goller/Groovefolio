# Groovefolio installation / local development

This repository is the Flutter source for Groovefolio.

## Clone

```powershell
git clone https://github.com/hunter-goller/Groovefolio.git
cd Groovefolio
```

## Install dependencies and generate sources

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Verify

```powershell
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
```

## Run

```powershell
flutter run
```

For Discogs development builds, pass `DISCOGS_CONSUMER_KEY` and `DISCOGS_CONSUMER_SECRET` with `--dart-define`. Never commit real credentials.

The internal Dart package name remains `vinyl_app`, so imports continue to use `package:vinyl_app/...` even though the product and GitHub repository are named Groovefolio.
