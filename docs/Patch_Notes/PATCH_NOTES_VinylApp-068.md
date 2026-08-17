# VinylApp-068 — Splash screen

## Summary

Adds a native Groovefolio splash screen and makes database readiness an explicit
part of application bootstrap.

## Implementation

- Added `flutter_native_splash`.
- Added light/dark native splash configuration, including Android 12+.
- Reused the approved Groovefolio 067 adaptive foreground for the light splash.
- Added a themed light-on-dark splash mark.
- Added `AppDatabase.initialize()` to explicitly force Drift's `LazyDatabase`
  open/migration lifecycle.
- `main()` preserves the native splash, waits for database initialization, then
  removes the splash only after Flutter paints its first frame.

## Theme values

- Light splash background: `#F7F4F0`
- Dark splash background: `#12100F`
- Dark splash mark: `#F5F1ED`

## Local commands

```powershell
flutter pub get
dart run flutter_native_splash:create
.\tools\verify_vinylapp_012.ps1
flutter run
```
