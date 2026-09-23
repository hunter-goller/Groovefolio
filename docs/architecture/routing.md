# Routing

Groovefolio uses `go_router` exposed through generated Riverpod `routerProvider`.

Current routes:

| Constant | Path | Screen |
|---|---|---|
| `collection` | `/` | Collection |
| `stats` | `/stats` | Stats |
| `discover` | `/discover` | Discover |
| `addAlbum` | `/album/new` | Add Record |
| `barcodeScan` | `/album/barcode-scan` | Barcode scanner |
| `albumDetail` | `/album/:id` | Album Detail |
| `editAlbum` | `/album/:id/edit` | Edit Record |
| `logPlay` | `/play/log` | Log Play |
| `settings` | `/settings` | Settings |
| `nfcHelp` | `/settings/nfc-help` | NFC help |
| `onboarding` | `/onboarding` | Interactive walkthrough |
| `discogsCollectionImport` | `/settings/discogs/import` | Discogs import |

Use `AppRoutes` constants/helpers instead of hard-coded route strings.

The OAuth return URI is `groovefolio://discogs-auth`. It is registered as a platform custom scheme and consumed by `app_links`; successful or failed callbacks route the user to `/settings`.
