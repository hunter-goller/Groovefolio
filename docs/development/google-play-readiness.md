# Google Play readiness

## Already established
- Flutter Android project
- CI/testing foundation
- local-first persistence
- deterministic schema migrations
- app-level product name: Groovefolio

## Before release
- final package/application ID decision
- keystore + signing
- target/compile SDK review
- app icon/adaptive icon
- splash/bootstrap
- screenshots/feature graphic/listing copy
- privacy policy/data-safety form
- accessibility pass
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
The current client reads a Discogs Consumer Key/Secret from build-time configuration for development. A secret compiled into a mobile APK should not be treated as truly confidential. Revisit the production auth architecture before public distribution.

User OAuth access credentials are stored with `flutter_secure_storage`; this is separate from protecting the app-level Consumer Secret.
