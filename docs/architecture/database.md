# Database architecture

Groovefolio uses Drift over a local SQLite database.

Production filename:

```text
vinyl_app_db.sqlite
```

The filename is a technical identifier retained from the project's original name.

## Current schema: v3

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

## Relationships

```text
Artists 1 ─── * Albums 1 ─── * Plays
                    │
                    ├── 0..1 NfcTags
                    │
                    └── * AlbumGenres * ─── 1 Genres
```

## Migration rule

`migration_v1.dart`, `migration_v2.dart`, and `migration_v3.dart` are historical schema definitions and must remain frozen. A new physical schema change gets a new schema version and migration file.

Fresh installs deliberately execute v1, then v2, then v3 so the resulting physical schema follows the same path as an upgraded database.

## Foreign keys

`AppDatabase` enables `PRAGMA foreign_keys = ON` in `beforeOpen` because SQLite foreign-key enforcement is connection-local.

## Schema verification

Run:

```powershell
.\tools\verify_vinylapp_012.ps1
```

The script exports the current Drift schema to `drift_schemas/drift_schema_v3.json` after tests pass.
