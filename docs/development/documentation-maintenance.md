# Documentation Maintenance

Documentation is stored with code so it can change in the same pull request.

## Source locations

- Root `README.md` — project landing page and high-level status
- `docs/implementation-status.md` — exact current `main` baseline
- `ROADMAP.md` — ordered project plan
- `CHANGELOG.md` — notable merged changes
- `docs/architecture/` — technical structure and boundaries
- `docs/development/` — development workflow
- `docs/decisions/` — durable decisions and tradeoffs
- `docs/features/` — feature requirements and implementation status
- `design/` — visual source assets and organization

## Source-of-truth rule

Only code merged into `main` is described as Implemented.

A feature branch, ZIP export, mockup, proof of concept, or abandoned branch must
be labeled Prototype, Experimental, or Unmerged. A completed checklist on a
Trello card does not override missing real dependencies or an unmerged PR.

For example, VinylApp-018 contains a fake-data Collection prototype, but the
current Collection status remains Placeholder/On Hold until the real provider
implementation is merged.

## PR documentation check

Ask these questions for every pull request:

1. Did setup commands or dependencies change?
2. Did a route, screen, or navigation contract change?
3. Did a table, relationship, type, or migration change?
4. Did provider ownership or lifetime change?
5. Did a repository or service contract change?
6. Did user-visible behavior change?
7. Did a roadmap item become complete, deferred, blocked, or reordered?
8. Does the documentation accidentally describe branch-only work as merged?
9. Did the change establish a durable decision that deserves an ADR?

Update only the affected documents.

## Status language

- **Implemented** — present in current `main`
- **Placeholder** — route/screen exists but feature behavior does not
- **Prototype** — experimental implementation outside `main`
- **Planned** — accepted roadmap work not implemented
- **On hold** — intentionally blocked
- **Deferred** — intentionally postponed

Never describe planned or prototype behavior as available.

## Changelog rules

The changelog records merged milestones. Do not list branch-only widgets or
screens under Added. Prototype work may be mentioned under a clearly labeled
Not included or Experimental section when it prevents confusion.

## ADR rules

Create or amend an ADR when a decision is expensive to reverse or affects
future structure. Do not rewrite an accepted decision to hide history; mark it
superseded and link to the replacement.

## GitHub Pages

The future site should build from Markdown merged into `main`. Repository
Markdown remains the source of truth and must stay readable without the site
generator.
