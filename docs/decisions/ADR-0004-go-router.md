# ADR-0004: Use GoRouter with Centralized Paths

- Status: Accepted
- Date: 2026-08

## Context

The app needs multiple top-level, task, and detail routes, including a dynamic
album ID. Navigation should be testable and should not scatter literal path
strings throughout widgets.

## Decision

Use `go_router`, expose the router through Riverpod, and define paths in
`AppRoutes`.

## Consequences

### Positive

- Route configuration has one owner.
- Dynamic album locations are represented as `/album/:id`.
- Navigation can use helpers such as `albumDetailPath(id)`.
- The router can be overridden in tests.
- The design can later adopt a shell route for persistent tabs.

### Negative / tradeoffs

- Actual Android App Links still require platform and domain configuration.
- Complex nested navigation will require careful route-tree design.

## Follow-up

- Add route-resolution tests for every location.
- Add a tab shell when bottom navigation is implemented.
- Configure external links only after a production domain is chosen.
