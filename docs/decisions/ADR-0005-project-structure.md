# ADR-0005: Use Feature-Oriented Presentation with Shared Layers

- Status: Accepted
- Date: 2026-08

## Context

A purely layer-first project can scatter one feature across many unrelated
folders. A purely feature-contained project can duplicate foundational routing,
database, and infrastructure code. Vinyl App needs a practical structure that
can grow without creating empty abstractions too early.

## Decision

Use feature folders for presentation and feature-local state, with shared
application layers for database, repositories, services, routing, theme, and
cross-feature widgets.

Add feature subfolders only when real code needs them.

## Consequences

### Positive

- Related screen code remains close together.
- Shared infrastructure has clear ownership.
- Empty architectural ceremony is minimized.
- A feature can grow into models, providers, and widgets without forcing every
  small feature to start with all of them.

### Negative / tradeoffs

- Teams must decide whether a provider or widget is feature-local or shared.
- Cross-feature workflows require discipline to avoid circular dependencies.

## Follow-up

Revisit boundaries after the first complete collection and play-logging flows.
