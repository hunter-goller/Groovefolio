# Services

A service coordinates the steps of a user operation. A repository reads or writes stored rows; a screen collects input and presents the result. Keeping the operation in a service makes its rules easier to test without building the whole UI.

## Responsibility and failure boundaries

| Service | Owns | Boundary a maintainer must preserve |
|---|---|---|
| `RecordWriteService` | Add/edit/import metadata across repositories | Its transaction runner and repositories must use the same database. Files and UI refresh are outside that transaction. |
| `PlayLoggingService` | Validate the album and record a play | Does not deduplicate manual plays or refresh providers. Repositories generate IDs and UTC timestamps. |
| `AlbumDeletionService` | Delete an album and its database associations | Database deletion commits before best-effort artwork removal. A cleanup failure does not restore the album. |
| `ArtworkStorageService` | Read/write/delete app-owned artwork | Writes supplied bytes without transcoding and can overwrite the existing album file. Does not update database paths. |
| `StatsService` | Collection and listening aggregates | Converts timestamps to local calendar time; malformed timestamps can fail parsing. Pass a fixed clock in tests. |
| `RecommendationService` | Deterministic suggestions from owned records | Uses local history, with rules preventing a candidate from supplying its own taste evidence. No remote recommendation engine. |
| `NfcService` | Physical tag read/write and local association | Tag bytes are written before the database link; replacing a link does not erase the old physical tag. |
| `NfcPlayLoggingService` | Scan, duplicate protection, and play insertion | Reserves duplicate protection before awaiting persistence to stop overlapping callbacks. |
| `NfcIntentPlayHandler` | Validate incoming album URI and log automatically | This URI path does not read a physical UID or verify an `NfcTags` mapping. |
| `DiscogsAuthService` | Direct OAuth and connected-account lookup | Credentials live in secure storage. Account lookup may fail due to network/provider errors without meaning the token was erased. |
| `DiscogsCatalogService` | Search and typed release metadata | Keeps external response interpretation out of screens. |
| `DiscogsCollectionImportService` | Preview, duplicate review, and per-record import | Earlier records can remain committed after a later error; artwork failures can be warnings. |
| `OnboardingService` / `WalkthroughController` | Persist progress and coordinate walkthrough steps | Replay uses real screens and operations except the intercepted practice delete; selected album state is not persisted. |
| `LocalDataResetService` | Clear local collection tables, then artwork | Database clearing can succeed before a filesystem error. Secure state remains. The Settings UI owns the debug-only entry gate. |

## Artwork is not part of a SQLite transaction

The filesystem and SQLite do not share one commit/rollback mechanism. Inspect the caller before changing ordering:

- **Add/import:** commit metadata first, then save artwork and attach its path.
- **Edit:** retain old bytes and replace artwork before the metadata transaction; on metadata failure, attempt to restore old bytes or remove the new file. A UI failure after the metadata commit must not trigger restoration. This recovery is best effort, not crash-atomic.
- **Delete:** commit database deletion first, then attempt file cleanup.

A failed final step therefore does not always mean “nothing was saved.” Return or present results that let the caller distinguish durable success, optional failure, and a failed main operation. The [developer guide](../developer-guide.md#7-key-workflows) follows the concrete callers end to end.

## Adding or changing a service

Inject dependencies instead of creating hidden global database/network clients. Keep user-interface concerns in callers, persistence mechanics in repositories, and cross-repository rules in the service. Wire dependencies through providers so tests can override them.

Define what null, empty lists, exceptions, and partial results mean. Identify which side effects can be undone and who owns cleanup. For an atomic metadata change, use the shared database transaction runner and verify failure rollback with actual SQLite. Test optional artwork/network failures separately from the metadata result.

The current mobile client communicates with Discogs directly. The draft Java backend in another repository is not wired into app `main`; do not add a backend URL and assume existing providers will use it. See [integration cutover](../developer-guide.md#12-future-development-notes) for the coordinated work required.
