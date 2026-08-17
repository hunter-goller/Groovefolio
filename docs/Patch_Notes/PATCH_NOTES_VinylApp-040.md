# VinylApp-040 change-set notes

> **Historical note:** This patch note predates the Groovefolio product rename. `VinylApp-###` remains the historical ticket prefix.


This overlay is based on the uploaded post-VinylApp-015 `main` ZIP and includes
both VinylApp-040 plus the small pre-017 repository-boundary cleanup reviewed in
this thread.

## Included

- NFC tag Drift table (`NfcTags`)
- one-to-one Album ↔ NFC tag rule enforced with unique `albumId`
- unique physical `nfcTagId`
- Album foreign-key enforcement and invalid-FK test
- schema version bump from v1 to v2
- immutable historical v1 DDL helper
- explicit v1 -> v2 migration
- fresh-v2 migration test
- genuine v1 -> v2 migration test preserving Artist + Album + Play
- one-query NFC tag -> Album lookup test
- AlbumRepository creation contract cleanup
- PlayRepository creation contract cleanup
- stale PlayRepository performance TODO removal
- startup/LazyDatabase comment correction
- repository tests updated for the application-facing creation APIs
- documentation/roadmap updates

## Required after applying

Generated Drift/Riverpod files are intentionally not included because the repo
ignores generated `*.g.dart` files.

Run:

```bash
dart format .
dart run build_runner build
flutter analyze
flutter test
dart run drift_dev schema dump lib/db/app_database.dart drift_schemas/
```

Commit the generated `drift_schema_v2.json` before merging VinylApp-040.

The schema snapshot is not included in this ZIP because the execution
environment used to build this overlay does not have Flutter/Dart installed and
should not fabricate Drift's canonical serialized snapshot.
