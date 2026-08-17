# VinylApp-067 patch notes

> **Product branding:** The app is now Groovefolio. `VinylApp-067` remains the historical ticket identifier.

## Implements

- approved Groovefolio v1 record + folio launcher identity
- 1024×1024 master launcher image
- transparent full-color icon mark
- Android adaptive foreground with safe-area padding
- Android 13+ monochrome/themed-icon foreground
- horizontal Groovefolio wordmark/reference asset
- launcher mask preview for circle, squircle, and rounded-square shapes
- `flutter_launcher_icons` as a dev dependency
- Android launcher generation config in `flutter_launcher_icons.yaml`

## Generate launcher resources

```powershell
flutter pub get
dart run flutter_launcher_icons
```

`flutter pub get` will update `pubspec.lock`; include that lockfile change in the PR.

## Verify

```powershell
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
flutter run
```

On the physical Samsung Galaxy S22 Ultra, verify that the icon is centered, readable, and unclipped with the active launcher mask. If Samsung still displays a cached icon after reinstalling, uninstall the debug app once and run it again.
