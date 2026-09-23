# Groovefolio documentation

Use these pages for the current `main` branch:

| Need | Read |
|---|---|
| Start development | [Cross-repo developer guide](developer-guide.md), [setup](development/setup.md), [testing](development/testing.md), [code generation](development/code-generation.md) |
| Understand the app | [Implementation status](implementation-status.md), [architecture](architecture/overview.md), [database](architecture/database.md), [routing](architecture/routing.md) |
| Explore behavior | [Feature index](features/README.md), [Discogs integration](integrations/discogs.md) |
| Prepare a release | [Release process](development/release-process.md), [Play readiness](development/google-play-readiness.md), [upload signing](development/android-release-signing.md) |
| Understand decisions | [Architecture decisions](decisions/README.md) |
| Review history | [Changelog](../CHANGELOG.md), [archived ticket notes](archive/README.md) |

The [roadmap](../ROADMAP.md) covers outstanding work. [Documentation maintenance](development/documentation-maintenance.md) explains how to keep these pages current. The [inventory](DOCUMENTATION_INVENTORY.md) lists the documentation areas.

## Names that intentionally differ

The product and repository are Groovefolio. The Dart package/import namespace is `vinyl_app`, the SQLite filename is `vinyl_app_db.sqlite`, the verifier is `tools/verify_vinylapp_012.ps1`, and historical tickets retain `VinylApp-###`. The permanent Android application ID is `app.groovefolio`.

Living pages describe current `main`; archived overlay and patch notes record their original ticket context and may contain obsolete instructions.
