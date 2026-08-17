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
