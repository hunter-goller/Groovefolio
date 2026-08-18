# VinylApp-107 — Discogs collection import

This is a changed-files-only overlay built from the merged VinylApp-090 repository supplied for VinylApp-107.

## What it adds

- paginated connected-account Discogs collection reads
- vinyl-only import filtering
- exact Discogs release-ID duplicate detection
- title + artist possible-duplicate review
- review screen before any writes
- new releases selected by default; review candidates are opt-in
- local Artist / Album / Genre/style / artwork / Discogs-link import
- progress UI
- per-release failure isolation and final summary
- Discogs attribution
- tests and current Discogs/collection documentation updates

No database schema bump is required. VinylApp-107 uses the schema-v4
`album_discogs_releases` table added by VinylApp-090.

## Verify

```powershell
.\tools\verify_vinylapp_012.ps1
```

Then launch with the Discogs development credentials:

```powershell
.\tools\run_dev.ps1
```

## Live Android check

1. Open Settings and confirm the Discogs account is connected.
2. Tap **Import Discogs collection**.
3. Confirm all collection pages load and the review summary appears.
4. Confirm non-vinyl items are ignored.
5. Confirm clearly new vinyl releases are selected automatically.
6. Confirm exact Discogs releases already in Groovefolio are disabled as already present.
7. Confirm possible title + artist matches are marked **Review** and start unchecked.
8. For the first live test, select only records you actually want written locally.
9. Start import and verify progress advances.
10. Confirm successful records appear in Collection with metadata, genres/styles, artwork when available, and preserved Discogs release identity.
11. Re-open the importer and confirm imported exact releases are now classified as already present.

If the verifier or live API flow fails, paste the full output/error before committing.
