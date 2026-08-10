# Feature Documentation

Feature pages describe target behavior and explicitly state current
implementation status.

| Feature | Current status |
| --- | --- |
| [Collection](collection.md) | Placeholder on `main`; data layer partially implemented; unmerged fake-data prototype on hold |
| [Add and edit album](add-album.md) | Placeholder Add route; AlbumRepository available but UI persistence not wired |
| [Album details](album-details.md) | Placeholder route with album ID |
| [Play logging](play-logging.md) | Placeholder route; Plays schema implemented; repository/service/UI still planned |
| [Statistics](statistics.md) | Placeholder route |
| [Discover](discover.md) | Placeholder route |
| [Recommendations](recommendations.md) | Planned |
| [Album Wrapped](album-wrapped.md) | Planned signature feature |
| [NFC](nfc.md) | Planned |

## Status terms

- **Implemented:** present in merged production code
- **Placeholder:** route exists but feature behavior does not
- **Prototype:** experimental work outside `main`
- **Planned:** accepted backlog work
- **On hold:** intentionally blocked by dependencies

## Standard feature-page sections

- Purpose
- Current status
- Intended user flow
- Data and dependencies
- Error and empty states
- Acceptance direction

A prototype branch does not change a feature to Implemented until the relevant
pull request is merged and its real acceptance criteria are met.
