# CI/CD

Groovefolio uses GitHub Actions from:

`https://github.com/hunter-goller/Groovefolio`

The project expects CI to catch formatting/analyzer/test/build problems that may not appear in a narrow local test run.

## What runs when

| When | Workflow | What it does | Time |
|---|---|---|---|
| Every pull request | `ci.yml` (check **Flutter CI**) | Format, analyze, tests, Drift schema check, NFC Kotlin tests | ~4 min |
| Every merge to `main`, or **Run workflow** | `ci.yml` | All of the above, plus the debug APK and the release App Bundle check | ~11 min |
| A pushed `v*` tag, or **Run workflow** | `release.yml` (**Release check**) | Checks the tag matches `pubspec.yaml`, runs the full `ci.yml`, and writes the steps to build the upload | ~12 min |

PRs skip the two app builds because they take most of CI's time. The NFC Kotlin
tests still compile the app's Android code on every PR (after
`flutter build apk --debug --config-only`), and the full builds run right after
each merge, so a release-only failure shows up on `main` immediately rather than
on release day. The required check name stays **Flutter CI**.

## Releasing a version

1. Bump `version:` in `pubspec.yaml` (for example `1.0.1+2`; the number after
   `+` must go up for every Play upload) and merge it.
2. Tag that commit and push the tag:

   ```powershell
   git checkout main
   git pull
   git tag v1.0.1
   git push origin v1.0.1
   ```

3. Wait for **Release check** on the Actions tab. It fails if the tag doesn't
   match `pubspec.yaml`. When it passes, its summary lists the commands to build
   the signed upload on your computer, as in
   [Android upload signing](../development/android-release-signing.md).

The upload key never goes to GitHub: CI only ever signs with a throwaway key to
prove the bundle builds and signs. Nothing is published automatically.

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

CI creates a disposable upload key, builds the release **App Bundle** (`flutter build appbundle --release`, the format Google Play requires) and checks with `jarsigner` that it is signed with that upload key and never the debug key. Key and AAB are discarded with the runner. CI does not produce a Play upload artifact or use the developer's actual upload key; build the real AAB locally as described in Android upload signing. See [Android upload signing](../development/android-release-signing.md).
