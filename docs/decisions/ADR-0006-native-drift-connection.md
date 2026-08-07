# ADR-0006: Open Drift through Native Core APIs

- Status: Accepted
- Date: 2026-08

## Context

The project uses Riverpod and Drift code generators with pinned compatible
versions. During setup, newer generator and analyzer dependency requirements
conflicted. A matching `drift_flutter` convenience layer also expected a newer
Drift API than the pinned core version.

## Decision

Do not depend on `drift_flutter` for the current connection setup. Open the
SQLite file with Drift core APIs:

- `LazyDatabase`
- `NativeDatabase.createInBackground`
- `path_provider` for the application documents directory
- `path` for the database file path

## Consequences

### Positive

- Avoids the incompatible convenience-package dependency.
- Retains a file-backed SQLite database and background execution.
- Keeps the connection injectable for tests.
- Makes connection behavior explicit.

### Negative / tradeoffs

- The project owns a little more platform connection code.
- Dependency upgrades must be evaluated as a compatible set.
- The decision may become obsolete after generator and Drift versions can be
  upgraded together.

## Follow-up

- Record dependency upgrades in a dedicated pull request.
- Run generation, analysis, all tests, and an APK build after any upgrade.
- Re-evaluate `drift_flutter` only when it provides a clear benefit and a
  compatible dependency graph.
