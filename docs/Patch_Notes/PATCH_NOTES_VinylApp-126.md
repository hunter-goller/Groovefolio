# VinylApp-126: Interactive onboarding draft

Base: `97cf7c9d0499747b013e93855fceb9008ac8e4f6` (main after Settings PR #81).
Trello: https://trello.com/c/cJSpbmnp

## Changes

- Optional Discogs connection using the existing connection card and OAuth controller.
- Real Add Record, import, Collection, Log Play, NFC Help, Stats and Discover actions.
- Versioned first-run progress; adding a record does not turn an unfinished walkthrough into an existing-user bypass.
- Preserve existing completion flags and populated-install bypass. Settings replay does not overwrite first-run progress.
- Guided direct add/play/import routes return to their caller; guided Collection/Stats/Discover tab visits use a pushed route.
- Preserve the live replay destination on OAuth callbacks; restore a pending first-run walkthrough after process death.
- NFC setup actions only on supported devices; manual use and Set up later remain available.
- Explain actual NFC behavior and local data without automatic backup.
- Friendly progress-storage errors and reduced-motion page changes.

## Validation status

This is an unvalidated draft, not a release-ready change. Dart 3.12.2 formatting and git diff whitespace checks pass locally.

Tests added/updated for progress after creating a record, legacy completion, resume/action return, replay, failed completion recovery, reduced motion, NFC visibility and existing tour navigation.

Flutter analysis/tests/builds have NOT run. Automatic approval review blocked local Flutter setup after a cloud metadata request, and the user subsequently authorized pushing the branch and opening a draft PR. CI results are pending.

## Before review/merge

Run dart format, dependency installation/code generation, flutter analyze, flutter test, Drift verification and the existing Android CI build/native-test gates.

Phone checks:
1. Fresh empty install: welcome appears; Skip completes; restart does not repeat it.
2. Stop at Add Record, save a real record, return, kill/relaunch: resume the saved step.
3. Existing collection/completed v1 install: no forced tour. Settings replay returns to Settings without resetting data/progress.
4. Optional Discogs: connect, cancel, deny, retry offline, and process-death callback. Verify correct return step and friendly feedback; no extra OAuth credentials added by this change.
5. Add/import/log cancel and success; explore tabs and return with Back. Check nested album edit/add flows as well as direct tutorial actions.
6. NFC-capable phone: choose an album, link an NTAG215 through Album Details, return, verify foreground Undo and outside-app confirmation. Unsupported/disabled devices remain usable manually.
7. Stats/Discover actions, small viewport, large font and reduced motion.

The separate accessibility draft PR #82 is not a dependency. Targeted upgrade What's new guidance and production Discogs backend cutover remain follow-up work.
