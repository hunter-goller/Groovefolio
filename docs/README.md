# Groovefolio documentation

The [developer guide](developer-guide.md) is the main onboarding and maintenance document. Its [task navigation](developer-guide.md#how-to-use-this-guide) lets you jump directly to setup, debugging, storage recovery, or adding a feature. It covers the app and website plus the explicitly marked backend draft stack.

Use these focused pages for the current app code:

| Need | Read |
|---|---|
| Start development | [Developer guide](developer-guide.md), [setup](development/setup.md), [testing](development/testing.md), [code generation](development/code-generation.md) |
| Find a feature's source and tests | [Feature-to-code map](developer-guide.md#feature-to-code-map), [workflow details](developer-guide.md#7-key-workflows) |
| Fix a bug or recover data | [Debugging checklist](developer-guide.md#debugging-checklist), [symptom map](developer-guide.md#symptom-to-code-map), [database recovery](developer-guide.md#database-recovery), [error recovery](features/error-recovery.md) |
| Add a field, screen, or service | [Feature recipes](developer-guide.md#feature-recipes), [migration procedure](developer-guide.md#migration-procedure), [coding standards](development/coding-standards.md) |
| Understand the app | [Implementation status](implementation-status.md), [architecture](architecture/overview.md), [database](architecture/database.md), [routing](architecture/routing.md) |
| Explore behavior | [Feature index](features/README.md), [Discogs integration](integrations/discogs.md) |
| Prepare a release | [Release process](development/release-process.md), [Play readiness](development/google-play-readiness.md), [upload signing](development/android-release-signing.md) |
| Understand decisions | [Architecture decisions](decisions/README.md) |
| Review history | [Changelog](../CHANGELOG.md), [archived ticket notes](archive/README.md) |

The [roadmap](../ROADMAP.md) covers outstanding work. [Documentation maintenance](development/documentation-maintenance.md) explains how to keep these pages current. The [inventory](DOCUMENTATION_INVENTORY.md) lists the documentation areas.

## Names that intentionally differ

The product and repository are Groovefolio. The Dart package/import namespace is `vinyl_app`, the SQLite filename is `vinyl_app_db.sqlite`, the verifier is `tools/verify_vinylapp_012.ps1`, and historical tickets retain `VinylApp-###`. The permanent Android application ID is `app.groovefolio`.

Living pages describe current `main`; archived overlay and patch notes record their original ticket context and may contain obsolete instructions.
