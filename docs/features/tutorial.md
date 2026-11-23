# Tutorial tracks (in progress)

The getting-started walkthrough is being rebuilt as a game-style tutorial themed as a record. This page covers the **progress model**, which is merged first; the screens and the spotlight guide come in follow-up PRs. Until then the existing 8-step walkthrough is unchanged.

## Tracks

| # | Side | Track | Badge | Needs a record | Counts towards gold |
|---|---|---|---|---|---|
| 1 | A | Add your first record | Crate Starter | | ✓ |
| 2 | A | Log a spin | First Spin | ✓ | ✓ |
| 3 | A | Check your stats (then Discover) | Number Cruncher | | ✓ |
| 4 | B | Tap to log with NFC | Tap Master | ✓ | optional |
| 5 | B | Swipe for quick actions | Smooth Operator | ✓ | ✓ |
| 6 | B | Back up your shelf | Safe Keeper | | ✓ |
| 7 | Bonus | Import from Discogs | Crate Digger | | optional |

- Tracks can be played in any order. One record is enough for every track; later tracks reuse whatever is on the shelf.
- **Locked:** a track that needs a record stays locked until the shelf has one.
- **Hidden:** NFC only appears on phones with NFC. Backup stays hidden until the backup feature ships (`backupTrackAvailableProvider`).
- **Gold record:** every visible required track completed. NFC needs a tag and Discogs needs an account, so neither blocks it.
- **Next track:** the first playable required track, then optional ones.

## Already done? It lights up

The collection is checked for evidence: any record completes Track 1, any play Track 2, any NFC tag Track 4. Someone who imports a large collection, or upgrades with an existing one, only plays what's left. Stats, swipe and backup leave no trace in the data, so they're only completed by playing them. Badges are kept even if the records that earned them are deleted later.

## Storage

Progress (completed tracks, intro seen, gold shown) is stored **on the device only**, in secure storage under `groovefolio.tutorial.progress.v1`, as JSON. There are no accounts. Unknown track names are ignored, so a newer app can add tracks safely. Track names are persisted, so they must never be renamed.

On first read, people who finished or started the old walkthrough are marked as having seen the intro. Old step numbers aren't mapped to tracks, because a step could have been skipped; the data decides instead.

If secure storage can't be read or written, the tutorial carries on in memory and never shows the intro because of the failure. It must never block access to the collection.

Code: `lib/features/onboarding/tracks/`. Tests: `test/features/onboarding/tracks/`.
