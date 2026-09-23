# Database architecture

Groovefolio uses Drift over a local SQLite database.

Production filename:

```text
vinyl_app_db.sqlite
```

The filename is a technical identifier retained from the project's original name.

## Current schema: v6

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

### v6 — deletion reliability + play history index
- rebuilds `plays.album_id` with `ON DELETE CASCADE`
- rebuilds `nfc_tags.album_id` with `ON DELETE CASCADE`
- adds `plays_album_played_at_idx` on `(album_id, played_at)`

This makes one album delete atomically remove database-owned play/NFC associations while artwork cleanup happens after the DB commit.

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

`migration_v1.dart` through `migration_v6.dart` are historical schema definitions once shipped and must remain frozen. A new physical schema change gets a new schema version and migration file.

Fresh installs deliberately execute v1 → v2 → v3 → v4 → v5 → v6 so the resulting physical schema follows the same path as an upgraded database.

The migration runner commits all required schema/data changes and SQLite's
`user_version` in one transaction. A failed migration rolls back to the prior
schema, version, and data so a new connection can retry it. Recording the version
inside that transaction also protects against interruption after migration commit
but before Drift finishes opening the database. A database from a newer app
version is rejected without downgrading its version or modifying its data.

This changes migration orchestration only: the schema remains v6, and frozen
migration files and snapshots are unchanged. It prevents partial upgrades going
forward; it does not automatically repair a database already damaged by an older
interrupted migration or reset user data when opening fails.

`test/db/migration_recovery_test.dart` uses file-backed SQLite databases to inject
failure after every migration write from fresh install and versions v1–v5,
compare the preserved schema/version/data through a connection with migrations
disabled, and retry on a new connection. It also covers failure after migration
commit, refusal to downgrade a newer database, and background-isolate opening.

## Foreign keys

`AppDatabase` enables `PRAGMA foreign_keys = ON` in `beforeOpen` because SQLite foreign-key enforcement is connection-local.

This runs outside the migration transaction because SQLite ignores changes to
`foreign_keys` while a transaction is active.

## Schema verification

Run:

```powershell
.\tools\verify_vinylapp_012.ps1
```

The script exports the current Drift schema to `drift_schemas/drift_schema_v6.json` after tests pass.
