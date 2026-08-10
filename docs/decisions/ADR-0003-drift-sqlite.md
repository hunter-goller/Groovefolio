# ADR-0003: Use Drift and SQLite for Local Persistence

- Status: Accepted
- Date: 2026-08

## Context

Vinyl App is intended to work offline and store relational data including
artists, albums, plays, and NFC associations. The app requires queries,
constraints, aggregations, migrations, and testable persistence.

## Decision

Use SQLite as the local source of truth and Drift as the Dart database layer.

## Consequences

### Positive

- Core features work without network access.
- Relational foreign keys express Artist → Album → Play relationships.
- Drift generates type-safe rows, companions, and query support.
- The database can run in memory for automated tests.
- SQL remains available for complex statistics and discovery queries.
- Versioned schema snapshots provide a durable migration baseline.

### Negative / tradeoffs

- Schema changes require migration discipline.
- Code generation is part of the development and CI process.
- Schema snapshots must stay synchronized with the Drift declarations.
- Future synchronization must reconcile remote data with a local source of
  truth.

## Current outcome

Implemented follow-up work now includes:

- Artists, Albums, and Plays tables;
- v1 migration and `SchemaVersions`;
- committed Drift v1 schema snapshot;
- empty → v1 migration test;
- first repository boundary through AlbumRepository.

Future schema versions must add explicit step-up migration tests instead of
rewriting v1 history.
