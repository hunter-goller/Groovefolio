# VinylApp-045/064 patch notes

> **Historical note:** This patch note uses the original `VinylApp-###`
> ticket prefix. The product is now named Groovefolio.

This change adds the Android NFC foundation without exposing unfinished NFC
controls in the app UI.

## Implements

- optional Android NFC permission and hardware declaration
- `NDEF_DISCOVERED` intent filter for `groovefolio://album/<album-id>` tags
- exact `flutter_nfc_kit` and `ndef` dependencies
- testable platform adapter for availability, polling, URI writing, and cleanup
- typed `NfcService` for:
  - availability checks
  - one-tag URI writing and local association persistence
  - foreground scan and repository album resolution
  - cancellation, timeout, unsupported, disabled, invalid, NDEF, and
    persistence failures
  - safe session cleanup and debug-only diagnostics
- focused service and manifest tests

The service never exposes a raw physical tag identifier to feature callers;
scans resolve locally to an album ID before the next UI flow consumes them.

## Not included yet

- record/detail controls for writing or rewriting tags
- Log Play NFC controls and automatic play logging
- physical-device validation with real tags

## Verify

```powershell
dart format .
dart run build_runner build
flutter analyze
flutter test
```
