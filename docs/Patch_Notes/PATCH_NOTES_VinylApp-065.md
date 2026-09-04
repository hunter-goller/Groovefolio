# VinylApp-065 patch notes

> **Historical note:** This patch note uses the original `VinylApp-###`
> ticket prefix. The product is now named Groovefolio.

This change builds on the merged VinylApp-045/064 NFC foundation. It exposes NFC
only on supported Android devices and keeps manual record creation unchanged.

## Implements

- availability-gated **Write NFC tag after saving** switch in Add Record
- album persistence before the optional hardware step begins
- modal write guidance while the phone waits for a tag
- friendly typed NFC errors without raw platform exception text
- **Try again** without creating a duplicate record
- **Skip for now** while preserving the saved record
- success and skipped-write confirmation messages
- service round-trip coverage proving a written tag resolves to its album
- widget coverage for unavailable, opt-in, success, retry, and active skip

## Still required before release

- run the full verifier after NFC dependencies resolve
- verify writing on the Galaxy S22 Ultra with a writable NDEF tag
- implement VinylApp-066 to scan a linked tag from Log Play

## Verify

```powershell
.\tools\verify_vinylapp_012.ps1
```
