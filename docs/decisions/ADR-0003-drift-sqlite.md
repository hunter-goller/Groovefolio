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

### Negative / tradeoffs

- Schema changes require migration discipline.
- Code generation is part of the development and CI process.
- Future synchronization must reconcile remote data with a local source of
  truth.

## Follow-up

- Add the Plays table.
- Add explicit schema export and migration tests.
- Implement repositories before feature UI relies on persistence.
