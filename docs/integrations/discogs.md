# Discogs through the Groovefolio backend

The app defaults to `https://api.groovefolio.app`. Discogs consumer keys, OAuth signing,
access tokens and verifier exchange live on the backend. The app contains no consumer secret.
Collection records, play history, NFC tags and imported artwork remain local.

## Connect and reconnect

In Settings, tap **Connect Discogs**. The app registers an installation on first use, saves
its random bearer token in platform secure storage, creates a backend authorization flow and
opens the allowlisted Discogs authorization URL. After authorizing in the browser, return to
Settings and tap **Check connection**. The backend callback page completes OAuth; it does not
currently launch the app automatically. A legacy custom-scheme return is only a hint to query
the saved flow; its token/verifier parameters are never accepted as proof of authorization.

Pending transaction ID and owner ID are saved securely before opening the browser. After a
process restart, Settings reads the account from the backend; Check connection also restores
pending flow state. Canceled, expired or failed flows offer another attempt. Cancel calls the
server, and Disconnect removes that installation's server-side Discogs connection. A network
failure preserves local state for retry. Disconnect does not delete local albums or revoke the
grant in Discogs' own application settings.

Users upgrading from the former direct Discogs integration must connect again. Legacy OAuth
credentials are never uploaded and are removed when connecting or disconnecting. Existing
local collection and listening data need no migration.

## Installation token lifecycle

`InstallationSession` registers only on explicit Connect. Settings/manual collection use does
not create installations. Tokens and pending successors are one JSON secure-storage value,
scoped to the configured backend origin. The app serializes authenticated requests and rotates
when less than three days remain on the backend's 30-day lifetime. It saves a cryptographically
random successor before sending it. After an ambiguous response or process death, it probes the
successor, then the original only if the successor is definitely rejected. Both are retained on
network, server or storage errors. A confirmed invalid token clears the saved session/flow and
asks for reconnection; mutations are not replayed and registration is not silently retried.

If the app does not use the backend for 30 days, the installation can expire and require a fresh
Discogs connection. The app has no background renewal worker. Lost successful registration
responses may leave an unused installation until backend cleanup; a later explicit retry can
register again. No token, OAuth URL, raw response body or credentials are printed in app logs.

## Catalog and imports

Search, barcode, release detail and owned collection calls use the installation bearer token.
The server selects collection ownership; the app never forwards a supplied username to the
backend. Normalized DTOs preserve release and instance IDs, genres/styles, track positions,
sides, durations and pagination. Duplicate review and local writes remain in the importer.
Artwork uses approved Discogs HTTPS CDN hosts without any bearer header. Redirects are disabled.

HTTP 429 stops the operation and exposes Retry-After as a typed failure; no tight retry loop is
used. The user can retry after waiting. An interrupted import preserves earlier successful
records; reload the preview to exclude those exact release IDs before retrying. The current
backend caps (30 catalog calls/minute per installation, shared server budgets and edge limits)
can interrupt large imports. Server outages and expired authorization do not erase local data.

## Development and device validation

Use `flutter run` or `tools/run_dev.ps1`; neither needs Discogs keys. To test a different backend,
use `--dart-define=GROOVEFOLIO_API_ORIGIN=https://your-test-api.example`. Only HTTPS origins with
no user info, path, query or fragment are accepted. Credentials are isolated per origin.

After CI passes, validate on an Android device against the Pi:

1. Open an existing collection and verify records/plays still work offline.
2. Connect from Settings, authorize in the browser, return and Check connection. Confirm username.
3. Cancel a fresh pending connection, then check the old browser URL cannot attach that flow.
4. Start again, close the app while the browser is open, authorize, relaunch and Check connection.
5. Search John Coltrane / Blue Train, select a release, and inspect artwork, genres and side/track data.
6. Scan a known barcode and review candidates before saving.
7. Preview your collection, review duplicates, import a few releases and verify local tracks/artwork.
8. Disable networking during a lookup and disconnect attempt; restore it and retry. The saved
   connection must not be reported successfully disconnected while the server was unreachable.
9. Disconnect, confirm the backend reports disconnected, and reconnect; local records stay intact.

Deterministic tests cover renewal timing/recovery, single registration under concurrency,
malformed JSON, DTO mapping, origin restrictions, artwork header isolation, flow recovery,
terminal statuses and failure retention. Live OAuth, Android secure storage and browser switching
require the device checklist. Tests and CI never use the Pi's staging bearer token or Discogs keys.
