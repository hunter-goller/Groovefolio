# Transparent NFC entry (VinylApp-128)

Android NDEF dispatch now targets `NfcEntryActivity`, not `MainActivity`.
The router has a translucent, preview-free theme and no Collection view.

- With a live Flutter host, the router delivers the intent directly and finishes.
  It never calls `startActivity` for MainActivity or moves the user's task.
- Without a live host, a non-exported transparent `NfcProcessingActivity` hosts
  Flutter in a separate, excluded-from-Recents task. Its texture-rendered content
  has zero alpha; database bootstrap and the first frame can still complete.
- The same retained engine is reused by the launcher/notification activity.
  This preserves the in-memory cooldown, subscriptions and database owner.
- External delivery IDs remain in flight until Dart completes persistence and
  feedback. Only the last valid completion closes the transparent host. A late
  completion never backgrounds MainActivity. A 30-second window timeout releases
  the transparent host without retrying or claiming the play failed.
- The native write/conflict gate still filters deliveries before AppLinks.

This is a transparent Activity implementation, not a permanent background service.
Android process termination can still interrupt work. No UI-flash guarantee is
made until physical validation on the target Android device.

## Galaxy S22 Ultra retest (full reinstall-over-existing build, no uninstall)

1. App backgrounded: tap a linked tag. No Collection/splash flash; exactly one
   play and one system notification; the previous app stays onscreen.
2. Remove the app from Recents, then repeat (do not force-stop in Settings).
3. Repeat the same tag within five seconds: no second play or notification.
   Remove it, wait six seconds, and tap again: one new play.
4. Tap the notification: the correct album opens with no extra play. Then tap
   a tag in the app: Undo and haptic only, no system notification.
5. Open Groovefolio while a cold tap is processing: it must stay open after
   the notification arrives, with no second database/engine or lost cooldown.
6. Test two different tags quickly; each valid play completes once.
7. Verify manual Save, Undo and the Jelly Roll/Taylor write-conflict protection.
8. Deny notifications: a saved external play gets the fallback message, never
   a permission dialog or visible Collection. Verify its count manually.

CI runs all `*Nfc*Test` native classes as well as the Flutter suite and both APKs.
