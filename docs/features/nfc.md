# NFC

- Current status: Planned

## Goal

Allow a physical NFC tag associated with a record to open a fast play-logging
flow.

## Intended flow

1. Confirm the device supports NFC.
2. Associate a tag identifier with an album.
3. Scan a tag.
4. Resolve the album locally.
5. Show a confirmation screen or prompt.
6. Log the play through PlayLoggingService.

## Requirements

- Core app features remain usable without NFC.
- Unsupported devices receive a clear fallback.
- Scans do not create a play without an intentional confirmation policy.
- Tag identifiers and album associations are stored locally.
- Permission and platform errors are represented explicitly.
- Tests use an adapter or fake scanner rather than physical hardware wherever
  possible.

## Security and privacy

Do not place sensitive collection details directly on a tag. Store only the
minimum identifier needed to resolve a local association. Document platform
permission requirements before release.
