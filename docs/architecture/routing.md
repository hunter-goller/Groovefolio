# Routing

Groovefolio uses `go_router` exposed through generated Riverpod `routerProvider`.

Current routes:

| Constant | Path | Screen |
|---|---|---|
| `collection` | `/` | Collection |
| `stats` | `/stats` | Stats |
| `discover` | `/discover` | Discover placeholder |
| `addAlbum` | `/album/new` | Add Record |
| `albumDetail` | `/album/:id` | Album Detail |
| `editAlbum` | `/album/:id/edit` | Edit Record |
| `logPlay` | `/play/log` | Log Play |
| `settings` | `/settings` | Settings / Discogs connection |

Use `AppRoutes` constants/helpers instead of hard-coded route strings.

The OAuth return URI is `groovefolio://discogs-auth`. It is registered as a platform custom scheme and consumed by `app_links`; successful or failed callbacks route the user to `/settings`.
