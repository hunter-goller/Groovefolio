# Groovefolio documentation

This directory is the living technical and product documentation for Groovefolio.

## Start here

- [Implementation status](implementation-status.md)
- [Architecture overview](architecture/overview.md)
- [Database](architecture/database.md)
- [Project structure](architecture/project-structure.md)
- [Development setup](development/setup.md)
- [Testing](development/testing.md)
- [Development seed](development/dev-seed.md)
- [Features](features/README.md)
- [Discogs integration](integrations/discogs.md)
- [Roadmap](../ROADMAP.md)

## Naming

The product and repository are **Groovefolio**:

`https://github.com/hunter-goller/Groovefolio`

Several technical/historical identifiers intentionally remain unchanged:

- Dart package/import namespace: `vinyl_app`
- Android application ID: `com.huntergoller.vinyl_app`
- SQLite filename: `vinyl_app_db.sqlite`
- verification script: `tools/verify_vinylapp_012.ps1`
- Trello/history IDs: `VinylApp-###`

Do not interpret these as stale branding; changing them has different migration/identity consequences than changing the visible product name.

## Documentation policy

Living docs describe the current `main` branch. Historical patch notes under `Patch_Notes/` describe the state at the time of those tickets and are not authoritative for current architecture.
