# Apply VinylApp-106 Part 2

This is a changed-files-only overlay intended for the Groovefolio baseline after the VinylApp-067 and VinylApp-068 overlays.

## Apply
Extract this ZIP over the repository root and allow matching files to be replaced.

Then run:

```powershell
flutter pub get
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
```

If 067/068 generators have not been run yet, run them first:

```powershell
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Live Discogs test
Run with your local Discogs application values:

```powershell
flutter run `
  --dart-define=DISCOGS_CONSUMER_KEY=YOUR_KEY `
  --dart-define=DISCOGS_CONSUMER_SECRET=YOUR_SECRET
```

Groovefolio sends the OAuth callback URI `groovefolio://discogs-auth` when requesting the temporary Discogs token.

Then open **Collection -> Settings -> Connect Discogs**.

Expected flow:

```text
Groovefolio Settings
-> system browser
-> authorize on Discogs
-> Groovefolio callback
-> Settings
-> Connected as <username>
```

Keep the `pubspec.lock` update created by `flutter pub get`.
