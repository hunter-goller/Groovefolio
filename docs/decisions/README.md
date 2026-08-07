# Architecture Decision Records

Architecture Decision Records (ADRs) explain durable choices and their
tradeoffs. They preserve context that is easy to lose when only the final code
remains.

## Status values

- Proposed
- Accepted
- Deprecated
- Superseded
- Rejected

## Index

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](ADR-0001-flutter.md) | Use Flutter for the application | Accepted |
| [0002](ADR-0002-riverpod.md) | Use Riverpod for state and dependency management | Accepted |
| [0003](ADR-0003-drift-sqlite.md) | Use Drift and SQLite for local persistence | Accepted |
| [0004](ADR-0004-go-router.md) | Use GoRouter with centralized paths | Accepted |
| [0005](ADR-0005-project-structure.md) | Use feature-oriented presentation with shared layers | Accepted |
| [0006](ADR-0006-native-drift-connection.md) | Open Drift through native core APIs | Accepted |

## Template

```markdown
# ADR-XXXX: Title

- Status: Proposed
- Date: YYYY-MM-DD

## Context

## Decision

## Consequences

### Positive

### Negative / tradeoffs

## Follow-up
```

When a decision changes, add a new ADR and mark the previous record superseded
rather than deleting its history.
