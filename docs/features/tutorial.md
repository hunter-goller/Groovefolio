# Tutorial tracks (in progress)

The getting-started walkthrough is being rebuilt as a game-style tutorial themed as a record, in three parts: the **progress model** (part 1), the **screens** (part 2) and the **spotlight guide** (part 3).

Parts 1 and 2 sit behind a switch that is **off by default**, so the existing 8-step walkthrough stays in charge until part 3 turns the new tutorial on and removes the old one. To try it:

```bash
flutter run --profile --dart-define=GROOVEFOLIO_NEW_TUTORIAL=true
```

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

## Screens (part 2)

- **Welcome** (`TutorialWelcomeScreen`): shown by `OnboardingGate` on a fresh install (intro not seen and no records). A spinning vinyl, the number of tracks and their badges. **Drop the needle** starts the next track; **Skip** opens the shelf. Either marks the intro as seen.
- **Track 1 choice:** "How do you want to fill your shelf?" offers **Import from Discogs** (opens Settings to connect and import) or **Add one by hand** (opens Add record). Discogs is never required.
- **Track 4 intro:** a sheet with the tag photo explains NFC and what you need, with **Skip for now**.
- **Playing a track:** a compact bar shows the track number, one instruction and **Stop**. Part 3 replaces this bar with the spotlight.
- **Track complete:** confetti, the badge, progress, then **Next: <track>**, **See your gold record** or **Back to my shelf**.
- **Tracklist** (`/tutorial`, Settings → Getting started): progress vinyl, Side A, Side B and the bonus track with locked, playable and completed states, then every badge.
- **Gold record** (`/tutorial/gold`): shown once after the last required track; replayable from the tracklist.

The vinyl only spins when the phone allows animations; confetti never moves.

### How tracks complete

Screens report what happened through `ref.tutorialEvent(...)`, which does nothing while the switch is off:

| Event | Where | Completes |
|---|---|---|
| Record saved | Add record | Track 1 |
| Play logged | Log play, NFC tap | Track 2 |
| Stats viewed, then Discover | Stats screen, bottom bar | Track 3 |
| NFC tag linked | Album detail | Track 4 |
| Row swiped open | Collection | Track 5 |
| Discogs import finished | Import screen | Bonus, and Track 1 if anything was imported |

Only the track being played is celebrated. Doing the same thing outside the tutorial earns the badge quietly.
