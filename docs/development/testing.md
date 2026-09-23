# Testing

Tests are executable examples of intended behavior. Start with the test nearest the code you are changing, then run the broader checks needed for its effects. The [feature-to-code map](../developer-guide.md#feature-to-code-map) links common operations to their source and tests.

## Commands and side effects

Run from the app repository root:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test test/services/record_write_service_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart run drift_dev schema dump lib/db/app_database.dart drift_schemas/
git diff -- drift_schemas/
```

Generation creates ignored `*.g.dart` files. Schema export writes versioned snapshots: inspect and commit intentional schema changes. The format command above checks formatting without rewriting files.

On PowerShell, the combined local verifier is:

```powershell
.\tools\verify_vinylapp_012.ps1
```

This script **formats source and writes the schema dump**, generates code, analyzes, and tests. Analyzer infos fail verification. Review its diff afterward. It does not run every Android build/signing/native test gate in CI.

For native NFC tests, run from `android/`:

```sh
./gradlew :app:testDebugUnitTest --tests '*Nfc*Test'
```

On PowerShell, use `.\gradlew.bat` with the same arguments. CI also builds debug and disposable-key release APKs. Neither those builds nor unit tests prove real phone/tag behavior.

## Choose the layer that proves the behavior

| Test layer | Useful for | Does not prove |
|---|---|---|
| Real in-memory Drift/SQLite | Queries, constraints, cascades, transaction rollback | Native file-opening permissions or physical device behavior. |
| Versioned migration fixtures | Preserving old data, schema changes, failure/retry | That a fresh database test alone covers upgrades. |
| Service with fakes | Rules, operation ordering, controlled failures | Actual SQL transaction behavior. |
| Provider/widget test | Refreshes, validation, loading/error/empty states, navigation | Camera/NFC hardware, OS delivery, real OAuth. |
| HTTP fixture/client test | Parsing, signing, retry/size/error rules | Real Discogs availability or provider-side configuration. |
| Native Android unit test | Intent gating and delivery rules | Full Android lifecycle behavior on a phone. |
| Physical device / isolated staging | End-to-end OS, hardware, browser, and service integration | Every edge case; retain deterministic automated coverage too. |

## High-value regression checks

- Record writes roll back all metadata on a required write failure; optional artwork warnings do not hide a successful metadata save.
- Edit preserves fields not represented in the form, including purchase/creation identity and existing release/track information.
- A mounted consumer refreshes after mutation. Recreating the screen/container can accidentally hide an invalidation bug.
- Migrations preserve old records and can retry after failure without advancing the schema version prematurely.
- Stats use a fixed clock and explicit local-calendar boundaries.
- NFC handles overlapping deliveries, persistence failure, expired/repeated Undo, and notification taps without inserting extra plays.
- OAuth handles cancellation, mismatched callbacks, secure-store failures, and identity lookup errors; imports distinguish per-item warnings from systemic failures after partial success.

Override providers and inject deterministic dependencies. Avoid live credentials or real network calls in app CI. Use actual SQLite when the assertion concerns SQL or rollback.

The draft backend has a separate Maven test suite. Its integration tests delete installation and registration-limit rows; use the [disposable database procedure](../developer-guide.md#backend-integration-tests-use-a-disposable-database), never a staging/production database with useful data.

## Investigating a failure

Run the failing test with expanded reporting, replacing the path:

```sh
flutter test -r expanded path/to/the_test.dart
```

Read the first relevant exception, not only the final failure count. Check SDK versions, dependency resolution, and whether generated files match the annotations before changing production code. A fake-repository pass alongside a SQLite failure usually points to persistence assumptions rather than the widget.

A previous Windows Flutter widget test hung on `Directory.systemTemp.createTemp()`. ArtworkPicker tests avoid that pattern and inject deterministic rendering. Keep widget rendering separate from filesystem tests where possible.

For user-visible symptoms, storage inspection, and device reproduction steps, use the [debugging checklist](../developer-guide.md#debugging-checklist).
