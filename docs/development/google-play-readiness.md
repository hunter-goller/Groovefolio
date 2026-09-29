# Google Play readiness

## Already established
- Flutter Android project
- CI/testing foundation
- local-first persistence
- deterministic schema migrations
- app-level product name: Groovefolio
- permanent Android application ID `app.groovefolio`
- launcher icon and splash assets
- privacy/support links in Settings
- release signing configuration that requires an explicit upload key

## Before release
- create and back up the upload key on the developer's machine using
  [Android release signing](android-release-signing.md); configure a signed AAB
- target/compile SDK review and final permission audit
- screenshots/feature graphic/listing copy
- review the published privacy policy against the actual build and complete Data Safety
- verify critical readability and reduced-motion behavior
- production error handling
- final dependency/security review

## Android backup policy

Groovefolio explicitly opts out of Android automatic cloud backup and
device-to-device transfer. The manifest sets `android:allowBackup="false"` and
references exclusion rules for both Android 11 and earlier and Android 12+.
Every supported app-private backup domain is excluded, including files,
databases, shared preferences, external app files, and device-protected storage.

This prevents Android from implicitly copying the local collection, play history,
artwork, NFC mappings, or encrypted credential files. It also means reinstalling
or moving to a new phone does not restore the Groovefolio collection.

A future user-controlled collection export/restore feature should use a
versioned, validated, SQLite-consistent format and include its referenced artwork.
It must remain independent of Android automatic backup and must never export
Discogs credentials or a backend installation token.

## Discogs-specific release work
The merged app calls `https://api.groovefolio.app`; the Java/Spring Boot backend
has been deployed behind Cloudflare Tunnel. The production app must not receive
Discogs consumer secrets or user OAuth credentials through build-time defines.

The app stores only its installation bearer token and pending flow metadata with `flutter_secure_storage`. Consumer secrets and user OAuth credentials stay on the backend. Validate the app/backend integration on-device before release.

## No-ads release

The release scope is ad-free: no AdMob SDK, advertising ID permission, banner
initialization, or consent SDK is included in `main`. Do not merge the separate
ads-preview PR #92 into this release. ML Kit's technical data collection still
needs Data Safety review; no ads does not mean no data leaves the device.

See [September 28 release audit](release-audit-2026-09-28.md) for the reconciled
Trello/code checklist and the privacy retention decisions still outstanding.
