# Play logging

Route: `/play/log` or bottom sheet from collection/detail flows.

## Current flow
- animated NFC prompt (visual/deferred until NFC scanning is implemented)
- manual collection search/selection
- choose date
- choose time
- choose side: full, side A, side B
- save through `PlayLoggingService`

`PlayLoggingService` validates that the album exists, then delegates persistence to `IPlayRepository`.

Play writes invalidate collection/search/play-count state so UI statistics refresh from the database.
