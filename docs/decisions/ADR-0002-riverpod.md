# ADR-0002: Use Riverpod for State and Dependency Management

- Status: Accepted
- Date: 2026-08

## Context

The app needs long-lived dependencies such as the database, replaceable
repositories for tests, route configuration, and future asynchronous feature
state. Constructing these dependencies directly inside widgets would make
lifecycle management and testing harder.

## Decision

Use `flutter_riverpod`, annotations, and Riverpod Generator.

- Wrap the app in `ProviderScope`.
- Expose the router through a provider.
- Expose the database through a `keepAlive` provider.
- Require future repository and service providers to be overrideable in tests.

## Consequences

### Positive

- Dependencies are resolved consistently outside widgets.
- Provider overrides enable focused tests.
- Lifetimes and disposal are explicit.
- Generated providers reduce manual boilerplate.

### Negative / tradeoffs

- The build step is required after annotated provider changes.
- Generator versions must remain compatible with the analyzer and other code
  generators.
- Poorly scoped providers can blur feature boundaries if conventions are not
  followed.

## Follow-up

Document feature-provider conventions as real stateful features are added.
