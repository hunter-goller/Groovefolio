# Play logging

Route: `/play/log` or bottom sheet from collection/detail flows.

## Current flow
- availability-gated animated NFC prompt with automatic foreground scanning
- registered NFC tag lookup that selects the linked record
- friendly unlinked-tag feedback with cancel and retry controls
- manual collection search/selection
- choose date
- choose time
- choose side: full, side A, side B
- save through `PlayLoggingService`

`PlayLoggingService` validates that the album exists, then delegates persistence to `IPlayRepository`.

Play writes invalidate collection/search/play-count state so UI statistics refresh from the database.

Opening Log Play from Album Details preserves its preselected record and does
not start an unnecessary NFC session. NFC selection fills the same form and
uses the same `PlayLoggingService` save path as manual selection.
