# VinylApp-065 patch notes

> **Historical note:** This patch note uses the original `VinylApp-###`
> ticket prefix. The product is now named Groovefolio.

This change builds on the merged VinylApp-045/064 NFC foundation. It exposes NFC
only on supported Android devices, supports both new and existing records, and
keeps NFC fully optional.

## Implements

- availability-gated **Write NFC tag after saving** switch in Add Record
- album persistence before the optional hardware step begins
- modal write guidance while the phone waits for a tag
- friendly typed NFC errors without raw platform exception text
- **Try again** without creating a duplicate record
- **Skip for now** while preserving the saved record
- success and skipped-write confirmation messages
- **Link NFC tag** from Album Details for existing records
- **Rewrite or replace NFC tag** for records that are already linked
- atomic association replacement without losing the previous link on a failed
  database update
- the same existing-record action for manual and Discogs-imported records
- service round-trip coverage proving a written tag resolves to its album
- widget coverage for unavailable, opt-in, success, retry, active skip, link,
  rewrite, and replacement behavior

## Still required before release

- verify first link, same-tag rewrite, and new-tag replacement on the Galaxy
  S22 Ultra with the ordered NTAG215 tags
- implement VinylApp-066 to scan a linked tag from Log Play

## Verify

```powershell
dart format .
dart run build_runner build
flutter analyze
flutter test
```
