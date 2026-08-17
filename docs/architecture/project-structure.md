# Project structure

```text
lib/
├─ db/
│  ├─ app_database.dart
│  ├─ database_provider.dart
│  ├─ migrations/
│  └─ schema/
├─ dev/
│  ├─ seed_main.dart
│  ├─ reset_seed_main.dart
│  ├─ seed_collection.dart
│  └─ dev_seed_artwork_source.dart
├─ features/
│  ├─ albums/screens/
│  ├─ plays/screens/
│  ├─ stats/screens/
│  └─ discover/screens/
├─ providers/
├─ repositories/
├─ routing/
├─ services/
│  └─ discogs/
├─ theme/
├─ types/
├─ utils/
└─ widgets/
   ├─ shared/
   └─ ui/
```

## Responsibilities

- `db/`: schema, frozen migrations, database connection/provider
- `repositories/`: persistence interfaces and Drift implementations
- `providers/`: feature state/composition above repositories
- `services/`: business workflows that should not live in widgets/repositories
- `features/`: route-level screens
- `widgets/`: reusable presentation components
- `theme/`: app-wide tokens/theme state
- `dev/`: debug-only seed/reset tooling
- `services/discogs/`: external Discogs auth/API foundation

## Naming note

The product is Groovefolio, but the Dart package remains `vinyl_app`. Keep imports such as:

```dart
import 'package:vinyl_app/db/app_database.dart';
```

until a dedicated technical package rename is intentionally planned.
