# Play Logging

- Route: `/play/log`
- Current status: Placeholder screen; Plays persistence exists, but the repository,
  service, providers, and real UI flow are not implemented yet

## Purpose

Record when a collector listens to an album, including whether the session was a
full album, Side A, or Side B.

## Implemented persistence foundation

The v1 database already contains the Plays table with:

- `id`
- `albumId`
- `playedAt`
- `sidePlayed`
- `createdAt`

`albumId` references Albums, and `SidePlayed` supports `full`, `sideA`, and
`sideB` through a Drift type converter.

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

## Remaining dependencies

- VinylApp-015 — PlayRepository
- VinylApp-016 — play repository provider
- VinylApp-017 — PlayLoggingService
- Riverpod feature state for selected album and form submission
- NFC service as an alternate entry path

AlbumRepository is already available from VinylApp-013.

## Reliability requirements

- Prevent duplicate submission from repeated taps.
- Allow historical timestamps.
- Make the result visible immediately.
- Preserve local-first operation.
