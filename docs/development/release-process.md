# Release Process

## Status

Vinyl App has no public release yet. This document defines the intended process
and will be refined before the first internal test release.

## Versioning

Public releases should use semantic versioning:

```text
MAJOR.MINOR.PATCH+BUILD
```

Before the first stable release, minor versions may represent major development
milestones.

The current `pubspec.yaml` version is Flutter scaffold metadata and should not
be treated as evidence that a public `1.0.0` release exists.

## Release readiness

A release candidate should have:

- A version and build-number update
- Passing CI from a clean checkout
- Successful release-mode Android build
- Migration tests for every supported schema upgrade
- Core integration tests
- Updated changelog and roadmap
- Reviewed privacy policy
- Store listing text, screenshots, icon, and feature graphic
- Manual verification on at least one supported physical Android device

## Proposed workflow

1. Create a release branch or release PR from `main`.
2. Update version and build number.
3. Move completed `[Unreleased]` changelog entries into a dated version section.
4. Run all automated and manual release checks.
5. Merge the release PR.
6. Create an annotated Git tag.
7. Build and distribute through the selected Android testing track.
8. Publish GitHub release notes from the changelog.

## Database rule

No release that changes the schema may ship without a tested migration path from
all supported installed versions.
