# Play Logging

- Route: `/play/log`
- Current status: Placeholder screen; Plays table is the next data-layer task

## Purpose

Record when a collector listens to an album, including whether the session was a
full album, Side A, or Side B.

## Intended inputs

- Album
- Played date and time
- Side: `full`, `sideA`, or `sideB`
- Origin: manual or NFC scan when that integration exists

## Intended flow

1. Select or scan an album.
2. Confirm timestamp and side.
3. Submit once.
4. Create exactly one Play record.
5. Refresh album detail, collection recency, and statistics state.

## Planned dependencies

- Plays table
- PlayRepository
- AlbumRepository
- PlayLoggingService
- Riverpod state for selected album and form submission
- NFC service as an alternate entry path

## Reliability requirements

- Prevent duplicate submission from repeated taps.
- Allow historical timestamps.
- Make the result visible immediately.
- Preserve local-first operation.
