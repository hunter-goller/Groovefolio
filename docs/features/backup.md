# Backup and restore

Settings → **Data** has two actions. Both stay on the device unless the user chooses otherwise; no Groovefolio server is involved.

## Back up collection

Creates one `.zip` file and opens Android's system **Save** dialog (Storage Access Framework), so the user picks the destination: Downloads, Google Drive or any other installed document provider. No storage permission is needed. The suggested name is `groovefolio-backup-YYYY-MM-DD.zip`.

## Restore from backup

For a new phone or a fresh install. It only runs when the collection has **no records**; otherwise it explains why and changes nothing. The user picks a file, sees what it contains ("17 records, 214 plays and 12 covers") and confirms. Everything is inserted in one transaction, so a damaged file or broken reference changes nothing. Leftover artists and genres with no records are removed first so they can't collide with the restored ones. Covers are written after the database commit; a cover that can't be saved is skipped and the record shows a placeholder.

Discogs is **not** included. Users reconnect it in Settings after restoring.

## File format (version 1)

| Entry | Contents |
|---|---|
| `groovefolio-backup.json` | `format: "groovefolio-backup"`, `formatVersion: 1`, `schemaVersion`, `exportedAt` (UTC) and `data` |
| `artwork/<albumId>.jpg` | Stored cover bytes, for albums whose cover file exists |

`data` has one array per table, with snake_case keys matching the database columns: `artists`, `albums`, `genres`, `album_genres`, `album_discogs_releases`, `tracks`, `plays`, `nfc_tags`. Albums carry `artwork` (the entry name or `null`) instead of the device-specific `artwork_path`. IDs are kept, so NFC tags written on the old phone (`groovefolio://album/<id>`) still log plays after a restore.

Not included: Discogs credentials, the backend installation token, onboarding progress and theme.

## Safety checks on restore

- The file must be a zip with the manifest, the right `format` and a known `formatVersion`. A newer version asks the user to update the app.
- Every row is type-checked; an unknown value (such as a `side_played` name) rejects the whole file.
- At most 50,000 entries and 512 MiB uncompressed.
- A cover is only read from exactly `artwork/<albumId>.jpg`, and only for IDs made of letters, digits, `-` and `_`, so no entry can write outside the artwork folder.

## Changing the format

When the schema changes, add the new fields, bump `BackupFormat.currentVersion`, and keep reading older versions so existing backups stay restorable. Code: `lib/services/backup/collection_backup_service.dart`; tests: `test/services/backup/`.
