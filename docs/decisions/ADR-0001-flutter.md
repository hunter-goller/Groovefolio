# ADR-0001: Use Flutter for the Application

- Status: Accepted
- Date: 2026-07

## Context

Vinyl App began as an earlier React Native prototype and was restarted in
Flutter. The application needs a maintainable mobile UI, local persistence,
strong tooling, and a path to an Android release.

The complete historical migration discussion was not recorded in the
repository. This ADR documents the current decision without inventing every
original rationale.

## Decision

Use Flutter and Dart as the application framework and language. Android is the
first intended release platform.

## Consequences

### Positive

- One UI toolkit and language across the application.
- Strong static analysis and formatting tools.
- First-class widget and integration testing support.
- Mature local database and navigation packages.
- Other platform runners remain possible without changing the core framework.

### Negative / tradeoffs

- The React Native prototype is not directly reusable.
- Dart and Flutter-specific patterns require learning and maintenance.
- Platform scaffolding does not guarantee every platform will be supported or
  tested.

## Follow-up

- Android is the planned release platform for the current product roadmap.
- iOS is not currently planned. Web and desktop can be reconsidered later if the project scope changes.
