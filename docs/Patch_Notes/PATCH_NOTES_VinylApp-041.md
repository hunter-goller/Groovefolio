# VinylApp-041 patch notes

> **Historical note:** This patch note predates the Groovefolio product rename. `VinylApp-###` remains the historical ticket prefix.


This changed-files-only overlay assumes the updated VinylApp-040 schema-v2 work
has already been applied (and ideally merged) first.

## Implements

- `INfcTagRepository`
- Drift-backed `NfcTagRepository`
- `create(albumId:, nfcTagId:, writtenAt:)`
- `findByTagId()` returning `null` when a tag is not registered
- `findByAlbum()` returning `null` when an album has no tag
- `delete()` by NFC association entity ID
- `nfcTagRepositoryProvider`
- in-memory repository tests
- relevant repository/provider/status documentation updates

The repository keeps generated IDs, UTC timestamp persistence, and
`NfcTagsCompanion` construction inside the persistence boundary, matching the
AlbumRepository and PlayRepository contract cleanup.

## Apply order

1. Finish/apply VinylApp-040.
2. Run build_runner so the v2 `NfcTag`/`NfcTagsCompanion` types exist.
3. Apply this VinylApp-041 overlay.
4. Run the verification commands below.

## Verify

```powershell
dart format .
dart run build_runner build
flutter analyze
flutter test
```

Generated `*.g.dart` files are intentionally not included in this ZIP because
they are generated locally and ignored by the repository.
