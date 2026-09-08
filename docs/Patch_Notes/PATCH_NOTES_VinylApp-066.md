# VinylApp-066 patch notes

> **Historical note:** This patch note uses the original `VinylApp-###`
> ticket prefix. The product is now named Groovefolio.

This change builds on VinylApp-065 and connects the existing foreground NFC
service and animated prompt to Log Play. Manual record selection remains fully
available whenever NFC is unavailable, disabled, cancelled, or unsuccessful.
It also handles Android-delivered album-tag intents and logs a full-album play
without requiring a manual Save action.

## Implements

- availability-gated NFC prompt in the Log Play record picker
- automatic foreground scan when Log Play opens without a preselected record
- registered tag lookup and automatic selection of the linked record
- exact **Tag not linked to any album** feedback for unknown tags
- friendly typed failure messages without rendering raw platform exceptions
- **Cancel scan** and **Scan again** controls that preserve manual search
- one active foreground poll at a time across rebuilds and repeated input
- cancellation when a record is selected manually or the screen closes
- no NFC prompt or poll when Album Details already preselects a record
- cold-start and warm-app Android NDEF intent handling
- automatic full-album logging through the normal `PlayLoggingService`
- five-second monotonic duplicate suppression per album
- safe handling for invalid URIs and deleted albums
- native Android suppression of automatic intents during foreground NFC
  writes/scans and for five seconds after reader mode closes
- Android system notifications for successful automatic NFC play logging,
  with album artwork when a safe local image is available
- in-app confirmation instead of a system notification for manual play saves
- debug-only software NFC tap flow that uses the same logging service
- widget coverage for availability, active scanning, linked and unlinked tags,
  cancellation, duplicate-session prevention, and preselection

## Still required before release

- verify scanning, cancellation, repeat scans, and unlinked tags on the Galaxy
  S22 Ultra with the ordered NTAG215 tags
- decide whether VinylApp-085 needs behavior beyond Android-delivered NDEF
  launch/resume handling

## Verify

```powershell
dart format .
dart run build_runner build
flutter analyze
flutter test
```
