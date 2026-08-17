# Release process

Groovefolio has not shipped a public Play Store release yet.

Before the first public release:
- finalize application branding/icon/splash
- confirm Android application ID strategy before publishing
- configure signing/keystore
- finish privacy/data-safety disclosures
- review Discogs production credential architecture and API terms/attribution
- run full verification and release builds
- test migration paths using preserved Drift schema snapshots
- verify offline collection/play/stats behavior
- verify any enabled account integration can be disconnected cleanly

Once an application ID is published, changing it creates a different Play Store app; treat that identifier separately from the Groovefolio display name.
