# VinylApp-128: Background NFC logging and one confirmation

Targets `main` after PR #77 (`VinylApp-127`) merged.

- Classify every accepted album-tag delivery before Android resumes the app:
  foreground when Groovefolio was already visible, external otherwise.
- External deliveries use a transparent NFC entry point without raising the
  Collection task, then reuse the existing Flutter/Drift NFC logging path.
- External success shows one Android notification. If notifications are denied
  or disabled, show one short system toast without retrying the insert.
- Foreground success shows the ten-second in-app Undo bar and light haptic only;
  it does not also post a system notification.
- Manual Save remains in-app only.
- Remove the Log Play NFC scanner. A tag consistently means “log a full album
  now”; manual Log Play is for side/date/time selection.
- Preserve per-album cooldown, identical-URI delivery, write-dialog gating,
  strict local album resolution, and notification-only navigation.

## Android limitation

NDEF dispatch is Activity-based. A transparent router forwards warm taps directly
to the existing host; a transparent, non-exported Flutter host processes cold
taps. The single retained engine preserves the cooldown and database owner.
Physical Samsung validation must confirm that no launch flash is perceptible.
See [transparent entry design and retest](../nfc-transparent-entry.md).

## Physical checks

- App visible: one play, light haptic, Undo bar, and no Android notification.
- App backgrounded: current app remains visible; one play and one notification.
- App terminated: launcher/home or current app remains visible; one play and
  one notification.
- Notifications denied: external tap logs once and shows one fallback toast.
- Notification tap opens the correct Album Details without another play.
- Manual Save shows only the existing in-app confirmation.
- Same tag within five seconds remains silent; after six seconds it logs again.
- Different albums do not suppress one another.
- Linked-tag write conflicts, retry, cancellation, and errors never auto-log.
- Log Play has no NFC prompt and still supports album, side, date, and time.
