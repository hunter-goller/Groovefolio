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

Use `AppRoutes` constants/helpers instead of hard-coded route strings.

Discogs connection callback/settings routes are not on the Part-1 baseline; they belong to `VinylApp-106` Part 2.
