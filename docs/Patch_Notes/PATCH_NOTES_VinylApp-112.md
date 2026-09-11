# VinylApp-112: NFC Help & Tag Store

Rebased onto main after PRs #77, #79 and #80 merged.

## Changes

- Offline, expandable NFC instructions at Settings > Help > NFC help & tags.
- Guidance covers choosing/placing stickers, write/rewrite/replace, automatic
  background notification versus in-app Undo, manual logging, duplicates,
  deleted-record errors and troubleshooting.
- Unsupported devices and disabled feature rollouts hide entry points; NFC
  switched off still allows help. Refresh availability when returning to help.
- Help links in manual Log Play and in failed-write dialogs.
  Opening help leaves the write dialog mounted inside its protected interaction.
- No backend, remote content fetch, analytics, or new permission required.
- Optional external store link with HTTPS destination validation, affiliate
  disclosure beside the CTA, and safe handling of launch exceptions/failures.
- No product price, stock, or shipping claims.

## Store activation intentionally pending

The Trello card does not identify the exact tested seller/product or supply an
approved affiliate URL. `nfcTagStoreUrlProvider` therefore returns null. The
store section explains that verified product links are coming soon and that
existing compatible tags can be used. Never substitute an unverified listing.

Affiliate activation is deferred to VinylApp-130; it does not block this page.
After verifying the exact product and Associates approval, publish a maintained
https://groovefolio.app/nfc-tags page with product guidance, affiliate disclosure,
and a clearly labeled Buy on Amazon link; then configure that URL in the
provider. Alternatively, a reviewed www.amazon.com/dp/ASIN URL is supported.
Website publication and affiliate enrollment are separate from this app PR.

Set GROOVEFOLIO_NFC_HELP_ENABLED=false for builds that must hide this feature.
The default is true on this NFC-enabled branch. The switch gates help, not the
underlying NFC feature. NFC rollout itself remains governed by merge/release.

## Evidence and validation

- NTAG215 user memory is 504 bytes per NXP:
  https://www.nxp.com/products/NTAG213_215_216
- User physically validated NTAG215 writing/tapping on Galaxy S22 Ultra;
  this does not establish compatibility for every seller or tag size.
- Widget tests cover available/disabled/unsupported states, feature hiding,
  navigation/back, large text at 360px, unconfigured store, affiliate disclosure,
  rejected URLs and failed external launching.
- Physical follow-up: return from Android NFC settings, read instructions on
  device, open help from a rejected write and return to the same error dialog,
  then confirm no unwanted play or navigation occurs.
