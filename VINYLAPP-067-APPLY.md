# VinylApp-067 apply notes

This changed-files-only overlay is based on the uploaded post-VinylApp-108 Groovefolio `main` ZIP and uses the **approved** Groovefolio logo direction from this chat.

## What changed

- replaces the earlier draft launcher concept with the approved record-emerging-from-folio mark
- adds the 1024×1024 master app icon
- adds transparent adaptive foreground and Android 13+ monochrome source
- adds the horizontal Groovefolio wordmark/reference artwork
- adds launcher-mask previews
- adds `flutter_launcher_icons: ^0.14.4`
- adds `flutter_launcher_icons.yaml`
- updates Groovefolio branding documentation

## Apply

Extract this ZIP over the root of the current Groovefolio repository, preserving directories and allowing the files in the overlay to replace matching files.

Then run:

```powershell
flutter pub get
dart run flutter_launcher_icons
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
flutter run
```

`flutter pub get` should update `pubspec.lock`. Keep that resulting lockfile change in the ticket branch/PR.

## Physical-device acceptance check

On the Samsung Galaxy S22 Ultra confirm:

1. Groovefolio no longer shows Flutter's default launcher icon.
2. The vinyl + folio mark is centered and large enough to read at launcher size.
3. Nothing important clips under the current launcher shape.
4. Circle/squircle/rounded-square behavior looks consistent with the included preview.
5. If Android themed icons are enabled, the monochrome mark displays cleanly.

If One UI keeps showing the old icon after reinstalling, uninstall the debug app once and run `flutter run` again to clear launcher caching.
