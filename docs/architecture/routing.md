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

The OAuth return URI is `groovefolio://discogs-auth`. It is registered as a platform custom scheme and consumed by `app_links`. Outside onboarding, callbacks retain the current Settings page and its Back destination, or push Settings over the current screen (Collection on a normal cold start). Repeated callbacks do not stack extra Settings pages. The saved backend transaction determines authorization success or failure; the return URI itself does not establish a connection.

An active walkthrough retains control of its return destination, and a pending first-run walkthrough resumes through Collection. Callbacks do not replace the onboarding screen or interrupt later walkthrough steps.
