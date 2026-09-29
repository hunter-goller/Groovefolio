# No-ads Android release audit — September 28, 2026

Scope: app main `59f7863`, backend main after PR #14, site main `2a70c02`, and
all 133 non-archived cards on [Vinyl App Dev](https://trello.com/b/e9B7pkq8/vinyl-app-dev)
across seven lists (124 task cards plus nine sequencing cards). This is a focused release/identity/data-flow review, not a
security certification or proof that the deployed Pi matches every repository setting.
No Trello cards were moved or marked complete during this audit.

## Verified in code

- Android Gradle namespace/application ID, Kotlin main/test packages, method
  channels and NFC task affinity use `app.groovefolio`. OAuth remains the fixed
  `groovefolio://discogs-auth` URI. No package rename is needed for Android.
- Historical Dart imports (`vinyl_app`) and database filename
  (`vinyl_app_db.sqlite`) are not Android application IDs. Do not rename the
  database as a branding cleanup: existing user data depends on its location.
- iOS/macOS/Linux scaffolding still has legacy identifiers; those platforms are
  not in this Android release scope. Audit identity/signing before shipping them.
- Version is `1.0.0+1`. Increment build number for subsequent Play uploads.
- Upload-key signing is implemented and fails closed; CI uses a disposable key.
  This is not proof that the real developer key has been created/backed up.
- No AdMob/UMP dependency, app AdMob initialization, or source AD_ID permission
  is included in main. PR #92 is separate and must not enter this no-ads release.
  Recheck the **final merged AAB manifest and dependencies**, not only source.
- Developer tools/seed entry points are debug-gated; debug banner is disabled.
- Discogs cutover is merged. The app retains an installation bearer token and
  pending transaction metadata; OAuth consumer/user credentials stay server-side.
- Camera barcode recognition uses ML Kit with auto-zoom. No ads does not mean
  no SDK technical data collection. Data Safety must include the final SDK review.
- Android backup exclusions, Settings privacy/support links, and the site's
  privacy/support pages and sitemap entries already exist.

## Release gates reconciled with Trello

| Card | Current board status | Actual remaining work |
| --- | --- | --- |
| [073 — developer account](https://trello.com/c/134qfAjp) | Backlog | Owner verification and Play Console setup; not verifiable from GitHub. |
| [074 — signing](https://trello.com/c/NTOh1xda) | Review | PR #87's code is merged. Create/back up the real upload key, build signed AAB, verify certificate. Do not close solely because CI uses a disposable key. |
| [075 — release config](https://trello.com/c/0Qv3LMJV) | Backlog | Most listed safeguards exist; verify actual release artifact, production origin, no seed/debug UI, target SDK, permissions and native-library compatibility. A new product-flavor architecture is not inherently required. |
| [076 — privacy](https://trello.com/c/VcKo8LdB) / [122 — website pages](https://trello.com/c/5up6nVzC) | Done | Existing published policy describes old direct-to-Discogs traffic. Review and publish server/Cloudflare/no-ads revision before distributing the new release. |
| [131 — Data Safety](https://trello.com/c/SR2pLhXM) | Backlog | Review installation identifiers, Discogs identity/credentials, search/barcode/import traffic, IP/rate limits, ML Kit, support and providers. Do not answer "no data collected" based on local collection storage. Complete applicable app-content, audience, access and deletion declarations. |
| [079 — integration tests](https://trello.com/c/VlGUd9YM) | Backlog | No integration_test directory is present. Add or document repeatable device tests for add → collection and log → stats, upgrade/data preservation, offline use, OAuth authorize/cancel/disconnect, barcode and NFC. |
| [071 — error recovery](https://trello.com/c/TYZuD6yp) | On Hold | App PR #69 remains open. Reconcile with merged backend changes, retest and resolve startup/database retry and post-save duplicate-write behavior before broad testing. |
| [072 — accessibility](https://trello.com/c/aH7FUcdh) | On Hold | PR #82 remains open. Broad work is deferred, but critical actions must remain usable with large text/TalkBack; inspect before release. No formal compliance claim. |
| [078 — widget tests](https://trello.com/c/JXiZnq2U) | Backlog | Several listed components already have tests; compare exact acceptance scenarios, particularly PrimaryButton. Do not rebuild the test suite from scratch. |
| [088 — listing](https://trello.com/c/ofeiOVSC) | Backlog | Final screenshots, feature graphic and store copy matching the no-ads/local-first build. |
| [089 — internal testing](https://trello.com/c/fqzJiEv9) | Backlog | Signed AAB upload and install through Play; inspect pre-launch findings and any Console testing/production-access requirements for this account. |
| [123 — website QA](https://trello.com/c/Sac0SYGK) | Backlog | Sitemap omission is already fixed in site PR #9; full Lighthouse/phone review remains unrecorded. |
| [124 — public launch cutover](https://trello.com/c/5JpupUlE) | Backlog | Real Play link/badge and released copy only once listing is public. Not a blocker for internal testing. |
| [125 — backend](https://trello.com/c/EgdRiyiV) | Backlog, stale description | Backend PRs and app #91 are merged; user reports Pi deployment. Close implementation work after device evidence; track retention, backups and recovery separately. |

## Backend/privacy follow-up before public release

- `InstallationService` expires authorization 30 days after registration/rotation.
  `DiscogsConnectionService.cleanup` removes expired/revoked connections and stale
  flows, but does **not** delete installation rows or their OAuth/catalog counters.
  Choose a bounded retention period and implement/test cleanup; the revised policy
  explicitly describes the current absence of automatic age-based deletion.
- Registration network hashes age out after 24 hours only when a later registration
  attempt runs cleanup. Do not promise deletion exactly 24 hours later.
- Disconnect deletes the current installation's Discogs connection/flows, not the
  installation itself, other installations, provider records, backups or local albums.
  Uninstall does not notify the backend. Document and test verified support-deletion
  handling, especially if the user has lost the installation token.
- Confirm actual Cloudflare/Pi logs and retention, backup existence/retention, encryption
  key recovery, and tested database restore. No backup schedule or log-retention duration
  can be inferred from the repository; do not invent one in a public policy.
- Ensure the real Pi stays powered/restarts services, restrict the dashboard/database
  to their intended interfaces, and verify public auth/rate limits after updates.

## Deferred, not required new features

Ads are out of scope. Skeletons (070), extra haptics/transitions (086/087), golden
tests (095), public devlog dashboard (097), trending/external recommendations (117),
affiliate activation (130), cloud backup/export and Wear OS can be separate decisions.
Card 117 still says "first public release" and conflicts with the current local-first
v1 direction; reconcile that wording explicitly rather than treating it as required.
Lack of export/backup is a real local-data-loss limitation to disclose to testers.

## Official release-policy references

- [Google Play User Data](https://support.google.com/googleplay/android-developer/answer/10144311)
- [ML Kit Android data disclosure](https://developers.google.com/ml-kit/android-data-disclosure)
- [Cloudflare Privacy Policy](https://www.cloudflare.com/privacypolicy/)

This review is implementation-grounded disclosure work, not legal advice or Play
approval. Validate Console requirements and the final artifact before submission.
