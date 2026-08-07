# Installing the Documentation Overlay

Copy the contents of this directory into the root of the Vinyl App repository.
Existing `README.md` and `.github/PULL_REQUEST_TEMPLATE.md` files are intended to
be replaced by the documented versions in this package.

Recommended workflow:

```bash
git switch main
git pull --ff-only
git switch -c docs/phase-1
```

Extract/copy the overlay, review the diff, then run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Open a documentation pull request and merge it into `main`. Do not create a
long-lived docs branch.
