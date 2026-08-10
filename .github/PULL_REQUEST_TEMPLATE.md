## Summary

<!-- What does this PR do, and why? -->

## Type of change

- [ ] New feature
- [ ] Bug fix
- [ ] Refactor (no functional change)
- [ ] Chore / tooling / CI
- [ ] Documentation

## Related

<!-- Link a Trello card (for example VinylApp-013), issue, or context. -->

## How was this tested?

- [ ] Automated tests added or updated
- [ ] `flutter analyze` passes locally
- [ ] `flutter test` passes locally
- [ ] Tested on Android (physical device or emulator)
- [ ] Manual verification is not applicable

<!-- Describe what was actually verified. -->

## Documentation impact

- [ ] No documentation change is required
- [ ] Relevant documentation is updated in this PR
- [ ] A named follow-up documentation task is required
- [ ] Status claims were checked against the behavior that will exist after merge

<!-- Identify affected docs and label any unmerged prototype work clearly. -->

## Screenshots / recordings

<!-- Add images or a recording for visual changes. Delete if not applicable. -->

## Checklist

- [ ] Acceptance criteria are met against real dependencies, not only fake data
- [ ] `dart format --output=none --set-exit-if-changed .` passes
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] `dart run build_runner build` runs clean when schemas/providers changed
- [ ] Drift schema snapshot is regenerated and committed when the schema version changes
- [ ] No leftover `print()` calls or temporary debugging code
- [ ] Generated `*.g.dart` files were not hand-edited or committed
- [ ] Branch-only prototypes are not documented as implemented
- [ ] Roadmap/changelog status is updated when appropriate
