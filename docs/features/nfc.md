# NFC

Groovefolio keeps NFC optional and local-first. The Android foundation,
availability-gated write and management flows, and foreground Log Play scan
flow are in place. Android NDEF intents can also launch or resume the app and
automatically log a full-album play. All hardware paths still require physical
validation before release.

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
- strict validation of incoming album URIs before local album resolution
- automatic full-album logging for Android NDEF intents at cold or warm start
- five-second, monotonic, per-album duplicate suppression
- foreground write/scan suppression so one tag tap cannot also become an
  automatic play, including delayed Android NDEF delivery after reader mode
- failed play inserts can be retried immediately
- debug-only software NFC tap flow that uses the production logging services
- Android system notification after a successful automatic tag-tap play,
  including the album title, what was logged, and bounded local artwork
- in-app confirmation for manual play logging and a safe in-app fallback when
  system notifications are unavailable or denied

## Still needed
- physical-device validation with the Galaxy S22 Ultra and NTAG215 tags
- decide whether VinylApp-085 has any remaining scope beyond the implemented
  Android NDEF launch/resume flow

## NTAG215 hardware checklist

Test tags before attaching them permanently to sleeves. Number the test tags so
results can be associated with the exact physical tag.

- link a blank tag while adding a new record
- link a blank tag to an existing manual or Discogs-imported record
- scan a linked tag from Log Play and confirm the correct record is selected
- tap a linked tag while the app is closed and confirm exactly one full play
- tap while the app is foregrounded and backgrounded
- keep the phone on one tag for repeated callbacks and confirm one play
- tap two different albums rapidly and confirm one play for each
- rewrite the same tag and replace an album's tag with another blank tag
- attempt to take a tag already linked to another album and confirm rejection
- confirm the rejected tag does not increment the original album's play count
- confirm automatic tag taps show a system notification with the correct album
  while manual Save shows only an in-app confirmation
- scan an unlinked, malformed, non-URI, and unrelated-URI tag
- delete a linked album, scan its old tag, and confirm a safe error with no play
- cancel and retry foreground reads and writes, including timeout cases

The NFC payload/association design should continue to keep the local database as the source of truth.
