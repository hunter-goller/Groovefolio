# CI/CD

Groovefolio uses GitHub Actions from:

`https://github.com/hunter-goller/Groovefolio`

The project expects CI to catch formatting/analyzer/test/build problems that may not appear in a narrow local test run.

## Local pre-push verification

```powershell
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
```

The verification script runs formatting, generated-source regeneration, analyzer, Flutter tests, and Drift schema export.

## Android SDK note

The current project compiles against Android SDK 36. `flutter_secure_storage` is pinned to stable `10.3.1`; the 11 beta requires SDK 37 and is intentionally not used on this baseline.

## Release compilation

CI creates a disposable upload key for the release APK compilation check and discards both key and APK. It does not produce a Play upload artifact or use the developer's actual upload key. See [Android upload signing](../development/android-release-signing.md).
