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
The current client reads a Discogs Consumer Key/Secret from build-time configuration for development. A secret compiled into a mobile APK should not be treated as truly confidential. The proposed Java/Spring Boot backend is separate, unmerged, and undeployed. Resolve and validate the production credential architecture before public distribution.

User OAuth access credentials are stored with `flutter_secure_storage`; this is separate from protecting the app-level Consumer Secret.
