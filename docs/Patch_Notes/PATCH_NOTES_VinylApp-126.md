# VinylApp-126 — guided walkthrough in the real app

Replaces the slide tour with one welcome screen, a compact guide panel and outlines around actual controls. The app screens remain interactive. The panel occupies its own space, scrolls with larger text and never covers form buttons or the navigation bar.

## Flow
1. Real Settings: Connect Discogs or Not now. Connected users can import their collection or choose Add manually.
2. Manual branch: Collection → Add record; enter title/artist, optionally search/scan, then save. Import branch: select/import records, review results and View collection.
3. Both branches: choose a real record and open Album Details.
4. Log a real play in the existing play form. Advance only after the save succeeds.
5. Optionally link/rewrite NFC from the real record menu; advance after successful writing, or choose Not now.
6. Swipe a real Collection row left. Edit opens the real form and saves normally. Delete is a safe practice tap during this step and cannot remove the record. Continue to Stats.
7. Tap Stats; inspect real listening results, then tap Discover.
8. Explore Discover and finish.

## Progress and navigation
- Skip step and Exit guide remain available. Skipping record selection also skips steps requiring a record.
- First-run progress uses v3 storage, separate from the old slide progress. Completed-install flags are preserved.
- Start or resume restores the saved step. Record-specific steps ask the user to select a record again after restart; no stale album ID is persisted.
- Replay from Settings does not change first-run progress or completion; exit/finish returns to Settings.
- A failed progress write can be retried without repeating a successful record/play write.
- Warm Discogs callbacks stay in Settings for the active guide; first-run cold callbacks return via the resume entry.
- Navigating elsewhere does not complete a step. The guide offers Return to guide.

## Phone verification
- Fresh test install: start, choose Not now, save a manual record; select it and log a play. Verify exactly one record/play was added.
- Replay: connect Discogs, import, review result, View collection; continue on an imported record. Also test canceled/denied login and a failed import.
- Back out of forms without saving: progress must not advance. Try an invalid form submission.
- Close/reopen midway after a save: resume the guide and choose a record when prompted.
- NFC supported: complete a write and check the guide advances. Cancel/unsupported: skip without blocking.
- Swipe left: Edit opens the real form; Save returns to Collection. Delete practice leaves data intact. Outside this guide step normal delete confirmation still works.
- Tap Stats and Discover using real bottom tabs; finish and replay again.
- Small screen, large fonts, keyboard open, light/dark theme: scroll guide/actions and forms independently; no overflow or hidden controls.

## Validation
Widget/controller tests cover real Settings branching, replay isolation, safe swipe-delete, progress write recovery, resume without stale IDs and large text. Full Flutter analysis/tests and Android builds run in PR CI. Physical OAuth/NFC testing is still required.
