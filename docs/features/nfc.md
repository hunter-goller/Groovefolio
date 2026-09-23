# NFC

Groovefolio keeps NFC optional and local-first. The Android foundation and
availability-gated write and management flows are in place. Android NDEF
intents automatically log a full-album play whether the app is visible or not.
Manual Log Play is reserved for choosing a side or custom date/time. All
hardware paths still require physical validation before release.

## Implemented
- schema v2 `NfcTags`
- one unique tag per album / one album per physical tag constraint
- `NfcTagRepository`
- lookup by NFC tag ID and album ID
- delete association
- album deletion cleans up linked NFC association
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
- no competing NFC scanner in Log Play: tag taps always mean automatic
  full-album logging, while manual logging owns side/date/time selection
- strict validation of incoming album URIs before local album resolution
- automatic full-album logging for Android NDEF intents at cold or warm start
- five-second, monotonic, per-album duplicate suppression
- a native Android gate shared by cold and warm activity entry points;
  cold-launch payloads are suppressed before Flutter/AppLinks attaches
- single-task Android launch behavior with the app's default task affinity to
  reuse the current Flutter navigation/dialog state for NFC and OAuth launches
- protection throughout the write dialog, including error and retry states,
  plus a monotonic five-second native cooldown after the interaction ends
- failed play inserts can be retried immediately
- automated service fakes for hardware-independent regression tests (the
  developer Settings fake-tap screen was removed in VinylApp-127)
- external/background tag taps return Groovefolio's task behind the current app
  and show one Android notification with album title, scope, and bounded local
  artwork; a short system toast is the fallback when notifications are disabled
- foreground tag taps show one ten-second in-app Undo confirmation and a light
  haptic, without also creating an Android notification
- manual play logging shows only its existing in-app confirmation
- native delivery metadata is queued per intent so repeated identical tag URIs
  retain their correct foreground/external classification
- notification permission prompts are never launched by an external tag tap
- after a successful tag link/write, permission is requested while Groovefolio
  is already visible so future external taps can post their notification
- duplicates and failed events never receive success feedback or app haptics
- notification taps navigate to the album without logging again

## Still needed
- physical-device validation with the Galaxy S22 Ultra and NTAG215 tags
- verify best-effort external task backgrounding on the Galaxy S22 Ultra;
  Android still delivers NDEF records through an Activity rather than a truly
  headless callback

## NTAG215 hardware checklist

Test tags before attaching them permanently to sleeves. Number the test tags so
results can be associated with the exact physical tag.

- link a blank tag while adding a new record
- link a blank tag to an existing manual or Discogs-imported record
- tap a linked tag while the app is closed and confirm exactly one full play
- tap while foregrounded and confirm only the Undo bar appears
- tap while backgrounded/closed and confirm the previous app remains visible
  while exactly one system notification appears
- keep the phone on one tag for repeated callbacks and confirm one play
- tap two different albums rapidly and confirm one play for each
- rewrite the same tag and replace an album's tag with another blank tag
- attempt to take a tag already linked to another album and confirm rejection
- confirm the rejected tag does not increment the original album's play count
- confirm the rejected tag does not emit an automatic-play notification
- leave the conflict dialog open for over five seconds and retry the linked
  tag: the dialog must stay open, with no play insertion or notification
- dismiss the dialog, remove the tag, wait five seconds, and confirm a fresh
  ordinary tap still logs exactly one play
- confirm OAuth browser returns, notification taps, and Android Back still
  return to the existing app task without another play or duplicate screen
- disable notification permission and confirm an external tap still logs once,
  displays one fallback message, and does not foreground Collection
- confirm manual Save shows only an in-app confirmation
- scan an unlinked, malformed, non-URI, and unrelated-URI tag
- delete a linked album, scan its old tag, and confirm a safe error with no play
- cancel and retry foreground writes, including timeout cases

The NFC payload/association design should continue to keep the local database as the source of truth.

## Lifecycle regression coverage

Dart tests cover the error/retry dialog lifetime, safe release, and a linking
interaction starting while an automatic play awaits album lookup. Native JVM
tests exercise the shared intent policy, ownership across activity instances,
cooldown, missing NFC data, and OAuth/launcher exclusions. CI also checks both
APK variants. These checks do not simulate Samsung's NFC dispatcher; physical
verification is still required. Debug builds emit only lifecycle entry, task ID,
and suppression decisions under the `GroovefolioNfc` log tag (no URI or album data).
