# VinylApp-090 — Discogs album autofill

Apply this changed-files-only overlay after VinylApp-067, VinylApp-068, and VinylApp-106 Part 2.

## What this adds

- Discogs release search from Add Record
- Up to five typed release matches with useful pressing metadata
- Exact release detail selection; Groovefolio never silently chooses a pressing
- Autofill for title, artist, year, label, genres/styles, and artwork
- Editable autofilled fields before save
- Discogs artwork persisted through `ArtworkStorageService`
- Exact Discogs release linkage in local schema v4 for duplicate detection and future import/barcode/track work
- Retry/empty/error states, including typed rate-limit failures
- Discogs attribution in the search UI
- Unit/widget/migration coverage

## Database change

Schema v4 adds `album_discogs_releases`:

- `album_id` — primary key, references Albums with cascade delete
- `release_id` — unique Discogs release ID

The migration preserves v1/v2/v3 data. The verifier will regenerate Drift sources and export the v4 schema dump.

## Verify

From the Groovefolio repository root:

```powershell
flutter pub get
.\tools\verify_vinylapp_012.ps1
```

If you have not yet generated the 067/068 native resources after applying those overlays, also run:

```powershell
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Live Discogs test

Run with the developer helper:

```powershell
.\tools\run_dev.ps1
```

Then:

1. Open Settings and connect Discogs if needed.
2. Open Add Record.
3. Tap **Search Discogs to autofill**.
4. Search by artist/title.
5. Select the exact release/pressing you own.
6. Confirm title, artist, year, label, genres/styles, and artwork are populated.
7. Edit any populated field if desired.
8. Add the record to the collection.
9. Reopen Add Record and confirm manual/offline entry still works normally.

Do not commit actual Discogs consumer credentials.
