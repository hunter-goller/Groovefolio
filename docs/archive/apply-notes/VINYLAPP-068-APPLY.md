# VinylApp-068 — Groovefolio native splash

Apply this overlay **after VinylApp-067**. It intentionally reuses 067's
`assets/branding/groovefolio_adaptive_foreground.png`.

## Apply

Extract this ZIP over the Groovefolio repository root.

Then run:

```powershell
flutter pub get
dart run flutter_native_splash:create
.\tools\verify_vinylapp_012.ps1
flutter run
```

Keep the generated native Android/iOS splash resource changes and the updated
`pubspec.lock` in the branch/PR.

## What 068 changes

- Adds `flutter_native_splash` as a runtime dependency because startup uses
  `FlutterNativeSplash.preserve()` / `remove()`.
- Uses Groovefolio light background `#F7F4F0`.
- Uses Groovefolio dark background `#12100F`.
- Uses the approved 067 Groovefolio mark for the light splash.
- Adds a light monochrome mark for the dark splash.
- Explicitly initializes Drift before `runApp`.
- Keeps the native splash visible until:
  1. Drift's database open/migration path completes, and
  2. Flutter paints its first frame.

## Acceptance test

On the S22 Ultra:

1. Force-stop Groovefolio.
2. Test once with system light mode.
3. Test once with system dark mode.
4. Confirm there is no white flash.
5. Confirm the splash uses the Groovefolio mark.
6. Confirm dark mode uses the dark Groovefolio background.
7. Launch once against an existing database as well as after a fresh install
   if practical.

If the splash appears stale after regenerating, uninstall/reinstall before
judging the result because native launch assets can be cached.
