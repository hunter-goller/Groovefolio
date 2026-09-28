# AdMob test-banner preview

This branch is a *test-only* integration. Normal builds, including APKs given
to testers, do not request ads. The Android manifest and banner unit use
Google's public sample IDs, not your AdMob account. Do not use this branch to
serve paid ads or ship it as a monetized Play build.

For a local Android test build, run:

```sh
flutter run --dart-define=GROOVEFOLIO_ADS_PREVIEW=true
```

Consent information is refreshed once per launch before any banner requests.
When required by your AdMob privacy message, Settings shows **Ad privacy
choices**. A consent failure hides ads; it never stops the collection app.
The adaptive test banner only appears above bottom navigation in Collection,
Stats and Discover. Walkthrough/onboarding, editing, play logging, scanning,
and Settings do not contain ads. Rotate the phone and switch tabs to check the
layout and lifecycle. Test banner requests require internet and can take time.

Before enabling real ads in a follow-up PR:

1. Set up an AdMob account and actual Android app and banner IDs. Never keep
   the sample application ID or banner ID in a live ad build.
2. Configure and test your consent messages, including EEA/UK testing and a
   Settings privacy-choices entry where UMP requires it.
3. Update the privacy policy and Play Data safety / Contains ads declarations
   for the ad SDK, and review children's/age-targeting policy if applicable.
4. Add an explicit production configuration and tests, then verify placement,
   consent, network-offline behavior and release builds on real Android devices.

The Discogs backend migration is independent: rebase this branch onto the
merged API branch after its physical-device tests pass.
