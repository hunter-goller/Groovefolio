# NFC

Groovefolio keeps NFC optional and local-first. The Android foundation,
availability-gated write and management flows, and foreground Log Play scan
flow are in place. Background/cold-launch entry points remain deferred until
the physical-tag workflow has been tested on a device.

## Implemented
- schema v2 `NfcTags`
- one unique tag per album / one album per physical tag constraint
- `NfcTagRepository`
- lookup by NFC tag ID and album ID
- delete association
- album deletion cleans up linked NFC association
- UI placeholders/prompts for future NFC behavior
- optional Android NFC permission and `NDEF_DISCOVERED` intent filter
- `FlutterNfcPlatformAdapter` boundary around `flutter_nfc_kit`
- typed `NfcService` for availability, foreground write, scan, cancellation,
  cleanup, and tag-to-album resolution
- URI payloads in the form `groovefolio://album/<album-id>`
- canonical hexadecimal tag identifiers before persistence
- unit and manifest coverage for the platform/service foundation
- availability-gated **Write NFC tag after saving** option in Add Record
- post-save write prompt with success confirmation, retry, and skip behavior
- failed or cancelled NFC writes preserve the already-created record
- **Link NFC tag** from Album Details for any existing record
- **Rewrite or replace NFC tag** for an already-linked record
- atomic association replacement that preserves the previous link if database
  persistence fails
- identical Album Details behavior for manually added and Discogs-imported
  records
- availability-gated animated NFC prompt in Log Play
- automatic foreground polling while the Log Play picker is open
- registered tag lookup that selects the linked record without logging it
  prematurely
- exact unlinked-tag guidance plus cancel and retry controls
- a single active scan across widget rebuilds, with cleanup on manual selection
  and screen disposal
- no scan when Album Details already supplied a preselected record

## Still needed
- physical-device validation of write, foreground scan, duplicate presentation,
  cancellation, and unknown-tag behavior with the Galaxy S22 Ultra and NTAG215
  tags
- background/cold-launch scan handling in VinylApp-085

The NFC payload/association design should continue to keep the local database as the source of truth.
