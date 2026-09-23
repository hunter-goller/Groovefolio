# Errors and recovery

An error message should explain what failed and what the user can do next. It must not expose a raw exception, promise that damaged data is safe, or claim a saved operation was rolled back.

## Where to look

| Boundary | Implementation | Recovery |
|---|---|---|
| Database opening/migration | `main.dart`, `AppStartup` | Show loading, then a friendly retry screen on failure. Retry creates a fresh provider container; no automatic reset or migration bypass. App links are created before the first attempt. |
| Collection, record, editor, Stats, Discover, onboarding | `AppErrorState` | Replace the failed view with a message and invalidate the relevant provider on Retry. |
| Log Play picker and Discogs identity | `AppErrorState.inline` | Keep the surrounding screen usable; retry the failed read. A failed identity lookup does not prove the user disconnected. |
| Artwork loading/decoding | `ResilientImage` | Show a local placeholder and an accessible unavailable label. A changed image gets a new load attempt. |
| Add / Log Play | Screen save handler | Record completion immediately after persistence. A later failure says the operation was saved; the same form's next action opens/exits instead of inserting again. |
| Edit artwork compensation | `EditAlbumScreen._save` | Restore old bytes only when metadata did not commit. If restoration also fails, say that the cover needs checking; never undo artwork because navigation failed after a successful save. |
| Discogs batch import | Import screen/service | Previously committed records remain. Refresh cached collection reads on success and failure; Retry refreshes identity and preview before another import. |
| Developer reset | Settings / `LocalDataResetService` | A filesystem failure can follow committed database clearing. Refresh views and warn of possible partial completion; never say nothing changed. |
| Physical NFC writing | `NfcWriteDialog` / `NfcService` | Keep the current typed device messages, retry and Skip behavior. The old `NFCPrompt` prototype is gone. |

`logAppError` writes diagnostic exception/stack details only in debug mode. Friendly UI copy is separate; release/profile builds omit this helper's output. It is not a remote crash-reporting service. Do not add credentials, callback URLs, authorization headers, or personal records to diagnostic messages.

## Debugging

Start with the [developer guide's debugging checklist](../developer-guide.md#debugging-checklist). Identify whether persistence completed before troubleshooting feedback/navigation. Reproduce using a small development collection. Never clear storage or reinstall as the first response to a startup failure: Groovefolio has no automatic collection restore.

Regression tests cover startup retry/repeated taps, collection provider retry, an Add follow-up failure without a duplicate save, failed play insertion followed by retry, partial import refresh, and broken artwork. Existing NFC tests remain the source of truth for tag behavior.

## Phone review before approval

1. Open Collection, Detail, Edit, Log Play, Stats and Discover, including empty states. Confirm ordinary navigation and onboarding still work.
2. Disconnect networking while checking a connected Discogs account. Retry after reconnecting; the local collection must remain usable.
3. Test a failed import in an isolated development setup. Previously imported records should appear, and a fresh preview should identify their exact release IDs as duplicates.
4. Use a missing/corrupt artwork file in a development build. Confirm a stable placeholder instead of an exception screen.
5. Exercise Add/Edit/Log Play failure cases with injected dependencies or test fixtures. Confirm messages distinguish persistence from follow-up failure and Retry does not create a second saved item.
6. Exercise startup failure using a test dependency or a preserved copy of a test database. Retry must not delete, reset, or downgrade the database.
7. Check error layouts at narrow width and large text. Retry should remain reachable by scrolling.
8. On a real phone, write/replace/skip a tag and exercise cold/warm NFC taps. Automated widgets cannot verify antenna or OS intent delivery.
