# Vinyl App Documentation

This directory is the documentation source for Vinyl App. It is written in
Markdown so the project architecture, implementation status, feature plans, and
release workflow stay close to the code.

Vinyl App is a personal application project, not an open-source project. These
docs are optimized for project continuity, engineering decisions, release
preparation, and portfolio presentation rather than external contributor
onboarding.

## Start here

- [Current implementation status](implementation-status.md)
- [Architecture overview](architecture/overview.md)
- [Project structure](architecture/project-structure.md)
- [Development setup](development/setup.md)
- [Roadmap](../ROADMAP.md)
- [Changelog](../CHANGELOG.md)

## Architecture

| Document | Question answered |
| --- | --- |
| [Overview](architecture/overview.md) | How is the application organized now, and what is the target flow? |
| [Project structure](architecture/project-structure.md) | What belongs in each folder? |
| [Dependency graph](architecture/dependency-graph.md) | Which layers and tickets unblock Collection? |
| [Routing](architecture/routing.md) | How are routes declared and resolved? |
| [State management](architecture/state-management.md) | Which Riverpod providers exist and which are planned? |
| [Database](architecture/database.md) | How is local data stored, versioned, and tested? |
| [Repository pattern](architecture/repository-pattern.md) | How does AlbumRepository separate Drift from feature code? |
| [Services](architecture/services.md) | Where will multi-step business logic live? |
| [CI/CD](architecture/ci-cd.md) | What does GitHub Actions verify? |

## Development

| Document | Purpose |
| --- | --- |
| [Setup](development/setup.md) | Install dependencies and run the app |
| [Code generation](development/code-generation.md) | Regenerate Riverpod and Drift code |
| [Coding standards](development/coding-standards.md) | Follow project conventions |
| [Git workflow](development/git-workflow.md) | Create branches and merge work |
| [Pull requests](development/pull-requests.md) | Prepare reviewable changes |
| [Testing](development/testing.md) | Understand current and planned tests |
| [Documentation maintenance](development/documentation-maintenance.md) | Keep docs synchronized with implementation |
| [Release process](development/release-process.md) | Prepare future versioned releases |
| [Google Play readiness](development/google-play-readiness.md) | Track polish, release, listing, and privacy tasks |

## Architecture decisions

The [ADR index](decisions/README.md) records durable technical decisions:

- Flutter application framework
- Riverpod for state and dependency management
- Drift and SQLite for local persistence
- GoRouter for navigation
- Feature-oriented presentation with shared application layers
- Direct native Drift connection setup

## Feature specifications

The [feature index](features/README.md) separates current implementation from
target product behavior.

## Documentation baseline

The current documented baseline includes:

- VinylApp-001 through 007 complete.
- VinylApp-008 deferred.
- VinylApp-009 through 013 complete.
- Artists, Albums, and Plays in Drift.
- Initial v1 migration and committed Drift schema snapshot.
- `AlbumRepository` and `albumRepositoryProvider` implemented.
- VinylApp-014 is the next repository task.
- All user-facing feature screens remain placeholders.
- VinylApp-018 remains an unmerged fake-data prototype and is on hold.

When code and documentation disagree, the merged repository is the source of
truth. A branch, ZIP, mockup, or prototype must be labeled as such until merged.
