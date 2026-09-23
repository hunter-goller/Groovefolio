# Release process

Groovefolio has not shipped a public Play Store release yet.

Before the first public release:
- verify final branding/icon/splash and the permanent `app.groovefolio` application ID
- create and back up the upload key, then build the signed AAB with
  [Android release signing](android-release-signing.md)
- compare the published privacy policy to the actual build and complete Play Data Safety
- review Discogs production credential architecture and API terms/attribution
- run full verification and release builds
- test migration paths using preserved Drift schema snapshots
- verify offline collection/play/stats behavior
- verify any enabled account integration can be disconnected cleanly

Once an application ID is published, changing it creates a different Play Store app; treat that identifier separately from the Groovefolio display name.
