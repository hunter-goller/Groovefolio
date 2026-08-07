# Coding Standards

The analyzer configuration is the enforceable source of truth. This guide
summarizes the most important project conventions.

## Formatting

Use the Dart formatter:

```bash
dart format .
```

The editor configuration uses LF endings, UTF-8, final newlines, and two-space
Dart/YAML indentation.

## Imports

Use package imports for project source:

```dart
import 'package:vinyl_app/db/app_database.dart';
```

Organize imports and avoid relative imports between `lib/` files. This is
enforced by `always_use_package_imports`.

## Dart style

The current lint configuration emphasizes:

- Explicit return types
- Strict casts, inference, and raw types
- `const` where possible
- Final locals and fields where possible
- Trailing commas
- Single quotes
- No `print()` calls
- Subscription cancellation
- Awaiting or explicitly handling futures

## Naming

- Files and folders: `snake_case`
- Types: `UpperCamelCase`
- Variables, methods, and providers: `lowerCamelCase`
- Routes: central constants in `AppRoutes`
- Trello-linked branches and PRs: include the `VinylApp-###` identifier

## Widgets

- Keep route-level scaffolds in `screens/`.
- Keep feature-only widgets under the owning feature.
- Put broadly reusable components under `lib/widgets/`.
- Pass callbacks into presentational widgets rather than resolving repositories
  inside them.
- Represent loading, empty, error, and data states explicitly.

## Providers

- Use generated Riverpod providers consistently.
- Document unusual provider lifetimes.
- Keep providers overrideable in tests.
- Do not expose Drift query builders to widgets.

## Database

- Place one Drift table class per file in `lib/db/schema/`.
- Use integer cents for currency.
- Use stable text identifiers rather than database-assigned IDs when the domain
  requires portable records.
- Add a migration before changing a schema used by released builds.
- Add in-memory tests for schema relationships and repository queries.

## Comments

Comments should explain constraints, tradeoffs, or non-obvious intent. Avoid
comments that only restate the code. Temporary code must include a removal
condition, as `RouteTestButtons` currently does.

## Documentation

Update the appropriate architecture, setup, feature, or ADR document when a
change alters behavior or a durable decision.
