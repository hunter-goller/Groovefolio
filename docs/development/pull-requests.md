# Pull Requests

Vinyl App is a personal project. Pull requests are used as a self-review and CI
quality gate before changes reach `main`, not as an external contribution
process.

A pull request should be small enough to review, complete enough to merge, and
clear enough to understand later from Git history.

## Required information

Use `.github/PULL_REQUEST_TEMPLATE.md` and include:

- Summary and motivation
- Type of change
- Related VinylApp task
- Actual test coverage and manual verification
- Screenshots or recordings for visual changes
- Documentation impact

## Recommended scope

Good examples:

- One schema table plus generated behavior tests
- One repository with its unit tests
- One feature screen and its supporting widgets/providers
- One architecture documentation update

Split unrelated refactors or cleanup from functional work when doing so makes
review clearer.

## Verification

Before requesting review:

```bash
dart run build_runner build
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

For Drift schema changes, also regenerate the schema snapshot. CI repeats the
core checks and verifies the committed snapshot.

## Documentation impact

Select one of the following outcomes:

- No documentation change is required.
- Relevant docs are updated in this PR.
- A named follow-up documentation task is required.

A schema, route, dependency, setup, architecture, or user-visible feature change
usually requires documentation.

## Merge readiness

A PR is ready when:

- CI passes.
- Acceptance criteria are met.
- Tests verify changed behavior.
- Temporary debugging output is removed.
- Generated code builds from a clean checkout.
- Drift snapshots are current when the schema changed.
- Documentation reflects the behavior that will exist after merge.
