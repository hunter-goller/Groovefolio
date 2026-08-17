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

## Discogs-specific release work
The current client reads a Discogs Consumer Key/Secret from build-time configuration for development. A secret compiled into a mobile APK should not be treated as truly confidential. Revisit the production auth architecture before public distribution.

User OAuth access credentials are stored with `flutter_secure_storage`; this is separate from protecting the app-level Consumer Secret.
