# Google Play Readiness

This checklist tracks the work needed to move Vinyl App from a development
project to a polished **Android release on Google Play**. Android is the current
release target; an iOS release is not planned at this time.

Google Play policies and submission requirements can change, so the current
requirements should be re-checked when release preparation begins.

## Product readiness

- Core collection, play logging, statistics, and navigation flows are complete.
- Empty, loading, error, and first-run states are intentionally designed.
- Destructive actions have confirmation or recovery where appropriate.
- The app has been tested with realistic collection and play-history data.
- Accessibility, text scaling, and common Android screen sizes have been reviewed.

## Quality

- `dart format --output=none --set-exit-if-changed .` passes.
- `flutter analyze` passes with no unresolved warnings.
- `flutter test` passes.
- Release builds are exercised on physical Android hardware.
- Database migrations are tested from previously released schemas.
- Crash-prone and data-loss-sensitive paths have targeted tests.

## Android release identity

- Final application name and Android package/application ID are confirmed.
- Version name and version code strategy is documented.
- Production Android signing is configured securely outside source control.
- Release icon, adaptive icon, splash screen, and branding are finalized.
- A release Android App Bundle (`.aab`) can be produced successfully.

## Google Play listing

- App name, short description, and full description are finalized.
- Phone screenshots are captured from the release build.
- Feature graphic and other required store artwork are prepared.
- App category and content information are selected.
- Support/contact information is current.
- Release notes describe shipped functionality rather than planned features.

## Privacy and Google Play data disclosures

Vinyl App is designed as a local-first application, but Play Console disclosures
must still match the behavior of the release build. Before publishing:

- Inventory every Android permission and external SDK in the release build.
- Document whether analytics, crash reporting, APIs, or external services transmit
  user or device data.
- Complete the Google Play Data safety information based on actual release behavior.
- Add a privacy policy if required by Google Play or by features added to the app.
- Verify that NFC, artwork, network, and storage behavior match the disclosures.

## Testing tracks

- Produce a signed release candidate from a clean `main` branch.
- Verify the app using an appropriate Google Play testing track before production.
- Install the Play-delivered build on physical Android hardware and smoke-test it.
- Verify upgrades from any prior test/release schema when migrations exist.

## Release process

- Run the full CI workflow and Android release-build verification.
- Perform a final smoke test using production configuration.
- Update `CHANGELOG.md`, implementation status, and roadmap.
- Upload the finalized Android App Bundle to Play Console.
- Complete the required Play Console release information and checks.
- Tag the repository release after the store-ready build is finalized.

## Out of scope

- Apple App Store / iOS release preparation
- TestFlight
- Apple signing, provisioning profiles, and App Store Connect

These can be added later only if iOS becomes part of the product roadmap.
