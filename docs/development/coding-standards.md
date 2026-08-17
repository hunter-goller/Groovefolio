# Coding standards

## Boundaries
- UI/services must not construct Drift companions.
- Repositories own persistence objects, IDs, and timestamps.
- Multi-repository workflows belong in services.
- External API JSON should be mapped before reaching widgets.

## Imports
The internal package remains `vinyl_app`:

```dart
import 'package:vinyl_app/db/app_database.dart';
```

## Formatting/analyzer

```powershell
dart format .
flutter analyze
```

Prefer running the full verifier before pushing:

```powershell
.\tools\verify_vinylapp_012.ps1
```

## Naming
Historical task/branch/commit references keep the `VinylApp-###` identifier even though the product is now Groovefolio.
