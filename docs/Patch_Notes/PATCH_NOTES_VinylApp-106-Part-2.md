# VinylApp-106 Part 2 — Discogs connection UX

## Added
- `/settings` route and Settings entry point from Collection
- Discogs connection card with disconnected, waiting, completing, connected, error, and disconnect states
- `app_links` callback handling for `groovefolio://discogs-auth`
- Android custom-scheme intent filter and explicit Flutter deep-link handoff
- iOS custom URL scheme registration and explicit Flutter deep-link handoff
- OAuth callback parsing and verifier completion through the existing `DiscogsAuthService`
- cancellation of pending request-token state
- connected username display and Discogs attribution/disclaimer UI
- tests for callback matching/controller behavior and Settings connection rendering

## Behavior
1. Settings → Connect Discogs requests a temporary OAuth token.
2. Groovefolio opens Discogs authorization in the system browser.
3. Discogs returns to `groovefolio://discogs-auth` with the request token and verifier.
4. Groovefolio validates the callback against the pending request token.
5. The verifier is exchanged for an access token/secret and stored in secure storage.
6. Identity lookup refreshes Settings to `Connected as <username>`.
7. Disconnect clears both saved access credentials and any pending request token.

## Notes
- Discogs remains optional; the local collection works without an account.
- Real Consumer Key/Secret values remain local build configuration and must not be committed.
- This overlay is intended to be applied after VinylApp-067 and VinylApp-068.
