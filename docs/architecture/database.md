# Database architecture

Groovefolio uses Drift over a local SQLite database.

Production filename:

```text
vinyl_app_db.sqlite
```

The filename is a technical identifier retained from the project's original name.

## Current schema: v5

### v1 — frozen baseline
- `artists`
- `albums`
- `plays`

### v2 — NFC
- `nfc_tags`

`album_id` and `nfc_tag_id` are unique, enforcing the current one-album/one-tag association.

### v3 — genres
- `genres`
- `album_genres`

Genre names use SQLite `NOCASE` uniqueness. `album_genres` has a composite primary key and cascade deletes for album/genre mappings.

### v4 — Discogs release linkage
- `album_discogs_releases`

Each local album can link to one exact Discogs release ID, and a Discogs release ID can only be linked once. The mapping cascades away when its album is deleted.

### v5 — tracklists
- `tracks`

Tracks belong to an album and cascade away with it. `sequence` preserves exact release ordering; optional `position`, `side`, and `duration_seconds` retain Discogs vinyl metadata such as A1/A2/B1/B2.

## Relationships

```text
Artists 1 ─── * Albums 1 ─── * Plays
                    │
                    ├── 0..1 NfcTags
                    │
                    ├── * AlbumGenres * ─── 1 Genres
                    ├── 0..1 AlbumDiscogsReleases
                    └── * Tracks
```

## Migration rule

`migration_v1.dart` through `migration_v5.dart` are historical schema definitions once shipped and must remain frozen. A new physical schema change gets a new schema version and migration file.

Fresh installs deliberately execute v1 → v2 → v3 → v4 → v5 so the resulting physical schema follows the same path as an upgraded database.

## Foreign keys

`AppDatabase` enables `PRAGMA foreign_keys = ON` in `beforeOpen` because SQLite foreign-key enforcement is connection-local.

## Schema verification

Run:

```powershell
.\tools\verify_vinylapp_012.ps1
```

The script exports the current Drift schema to `drift_schemas/drift_schema_v5.json` after tests pass.
