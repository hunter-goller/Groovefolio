# VinylApp-091 — Barcode scanning overlay

Baseline: Groovefolio main after VinylApp-114 (schema v6).

## What this changes

- Adds `mobile_scanner` for UPC/EAN camera scanning.
- Adds Android/iOS camera permission declarations.
- Adds `/album/barcode-scan` and a full-screen scanner.
- Adds **Scan barcode** to Add Record.
- Adds authenticated Discogs vinyl-only barcode search with UPC-A/EAN-13 leading-zero fallback.
- Shows matching pressings and requires the user to choose the exact release.
- Reuses the existing hardened Discogs transport and the VinylApp-114 `RecordWriteService`, so selected release ID, genres, tracks, and metadata still save through the atomic record-write path.
- Adds barcode normalization and Add Record barcode-flow tests.

## Apply

Extract this overlay into the repository root and allow changed files to overwrite the existing versions. Then run:

```powershell
flutter pub get
.\tools\verify_vinylapp_012.ps1
```

## Physical-device acceptance

On the Galaxy S22 Ultra:

1. Run `./tools/run_dev.ps1` (PowerShell: `.\tools\run_dev.ps1`).
2. Open **Add a record** → **Scan barcode**.
3. Grant camera permission.
4. Scan a real UPC/EAN on a vinyl jacket.
5. Confirm Groovefolio shows vinyl Discogs matches instead of silently choosing one.
6. Pick the correct pressing and verify title/artist/year/label/genres/artwork/tracklist autofill.
7. Save and verify the album retains its Discogs release ID and tracklist.
8. Also verify a barcode with no Discogs match shows the not-found state cleanly.
