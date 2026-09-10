# Play logging

Route: `/play/log` or bottom sheet from collection/detail flows.

## Current flow
- manual collection search/selection
- choose date
- choose time
- choose side: full, side A, side B
- save through `PlayLoggingService`

`PlayLoggingService` validates that the album exists, then delegates persistence to `IPlayRepository`.

Play writes invalidate collection/search/play-count state so UI statistics refresh from the database.

Opening Log Play from Album Details preserves its preselected record and does
not start an NFC session. A physical NFC tag always means “log a full-album
play now”; Log Play remains the explicit flow for choosing a record, side, or
past date/time before saving.
