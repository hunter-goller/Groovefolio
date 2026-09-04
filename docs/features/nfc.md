# NFC

Groovefolio keeps NFC optional and local-first. The Android foundation and the
availability-gated Add Record write flow are now in place. Scan-to-log entry
points remain hidden until the physical-tag workflow has been tested on a
device.

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

## Still needed
- edit/detail UI for writing or rewriting a tag
- scan handling in Log Play and foreground auto-log play
- foreground scan → album lookup → auto log play
- physical-device validation with the Galaxy S22 Ultra and the chosen tags

The NFC payload/association design should continue to keep the local database as the source of truth.
