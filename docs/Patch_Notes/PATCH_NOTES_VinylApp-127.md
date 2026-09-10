# VinylApp-127: NFC confirmation polish

Stacked on PR #76 at 7349715. Preserve its tag-writing collision fixes.

- NFC success retains the local Android notification and adds a ten-second
  in-app Undo action. Manual logging remains in-app only.
- Undo holds a capability to delete only the exact newly inserted Play ID,
  consumes it before awaiting, and expires using monotonic time. It cannot be
  invoked from a tag/URI. It is intentionally unavailable after process death.
- Undo refreshes collection, album, picker, stats and recommendation providers
  and cancels that play's notification. It does not clear the duplicate guard.
- Successful automatic logging triggers one light platform haptic. Suppressed
  or failed events trigger neither notifications nor haptics.
- Notification taps use an explicit immutable navigation-only intent, strictly
  validate the album ID, resolve it locally, and retain Collection as a back
  destination. Deleted albums produce safe feedback without another play.
- Notifications use string play-ID tags rather than integer hashes for identity.
- Remove the developer fake-tap screen and its obsolete UI test; retain NFC
  service test doubles and physical-path regression tests.
- Enable CI for PRs targeting the NFC integration branch while stacked.

## Physical checks before merge

- Normal tag tap: one play, system notification with artwork, light haptic,
  and in-app Undo. Undo removes only that play and its notification.
- Notification permission denied: logging and in-app Undo still work.
- Manual Save: in-app confirmation only, no NFC notification/haptic.
- Duplicate tap within five seconds: no extra play, notification, or haptic.
- Undo after ten seconds cannot remove anything. Older manual plays survive.
- Notification tap with app cold/warm: correct Album Details, Back to Collection,
  and no increment. Deleted album: safe message, no increment.
- Recheck rejected linked-tag writing: dialog remains open, no play/notification.
- Developer Settings contains reset but no Test NFC Tap.

After #76 merges, rebase only this branch's changes onto main and retarget its
PR to main. Do not merge this stacked PR into the integration branch.
