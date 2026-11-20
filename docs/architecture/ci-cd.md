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

## Flutter version and lockfile

CI pins Flutter `3.44.9` and installs dependencies with `flutter pub get --enforce-lockfile`, so a build fails instead of silently resolving different package versions. Commit `pubspec.lock` whenever `pubspec.yaml` changes. Upgrade Flutter on purpose, in its own PR, and commit the lockfile it produces in the same change.

## Android SDK note

The current project compiles against Android SDK 36. `flutter_secure_storage` is pinned to stable `10.3.1`; the 11 beta requires SDK 37 and is intentionally not used on this baseline.

## Release compilation

CI creates a disposable upload key for the release APK compilation check and discards both key and APK. It does not produce a Play upload artifact or use the developer's actual upload key. See [Android upload signing](../development/android-release-signing.md).
