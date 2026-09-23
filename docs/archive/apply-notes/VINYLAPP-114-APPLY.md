# VinylApp-114 — apply + verify

This overlay is based on `Groovefolio-main(7).zip` with VinylApp-105 already merged.

## What it changes

- adds `INTERNET` to the main Android manifest so release variants keep networking
- adds a CI release APK build check **without uploading/publishing an artifact**
- adds schema v6:
  - `Plays.album_id` -> `ON DELETE CASCADE`
  - `NfcTags.album_id` -> `ON DELETE CASCADE`
  - `plays_album_played_at_idx (album_id, played_at)`
- makes album deletion one canonical DB delete followed by best-effort artwork cleanup
- moves Add/Edit/Discogs-import multi-repository DB writes behind `RecordWriteService` and one outer Drift transaction
- hardens `DiscogsApiClient` with trusted HTTPS artwork hosts, no OAuth header on CDN artwork requests, response limits, timeout/retry handling, typed malformed responses, and `Retry-After` support
- stops collection import batches on systemic auth/rate-limit/network failures instead of repeatedly failing every remaining release
- adds focused migration, transaction, deletion, import, and Discogs client regression tests

## Apply

Extract this ZIP over the root of the current Groovefolio checkout and allow files to overwrite.

## Verify

Run:

```powershell
flutter pub get
.\tools\verify_vinylapp_012.ps1
```

The verifier should generate `drift_schemas/drift_schema_v6.json`. **Include that generated v6 schema snapshot in the 114 commit/PR.**

Then push the PR and let GitHub Actions run. CI builds debug and release APK variants only as verification. There is intentionally no `actions/upload-artifact` step, so neither APK is published as a GitHub artifact.

## Play Store work intentionally deferred

VinylApp-114 does not configure production Play signing, upload an AAB/APK, move the Discogs consumer secret to a backend, or complete privacy/Data Safety work. Those remain release-readiness tasks.
