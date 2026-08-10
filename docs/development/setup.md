# Development Setup

## Prerequisites

- Git
- Flutter stable
- Dart compatible with the project's `^3.12.2` constraint
- Android SDK and an emulator or physical Android device
- VS Code, Android Studio, or another Flutter-capable editor

The intended release target is Android through Google Play. Other Flutter
runners are present but are not treated as supported release platforms.

## Clone and install

```bash
git clone https://github.com/hunter-goller/vinyl-app.git
cd vinyl-app
flutter doctor
flutter pub get
```

Resolve any required Android toolchain items reported by `flutter doctor`.

## Generate source

Generated Riverpod and Drift `*.g.dart` files are ignored by Git and must be
created locally:

```bash
dart run build_runner build
```

See [code generation](code-generation.md).

## Verify the project

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

For database-schema changes, also run:

```bash
dart run drift_dev schema dump lib/db/app_database.dart drift_schemas/
```

and review/commit the appropriate snapshot.

## Run the app

List devices:

```bash
flutter devices
```

Run on the selected device:

```bash
flutter run
```

The current application opens the database at launch and displays the Collection
placeholder screen. Temporary buttons allow every route to be visited.

## Common development loop

```bash
# After editing annotated providers or Drift tables
dart run build_runner build

# Before committing
dart format .
flutter analyze
flutter test
```

## Database location

Production uses a file named `vinyl_app_db.sqlite` in the platform application
documents directory. Automated database and repository tests use in-memory
SQLite and do not write to the device filesystem.

## Resetting local development data

The project now has a versioned v1 baseline, but it is still pre-release. During
development, uninstalling the app or clearing application data is acceptable
when intentionally resetting local test data. Once public releases contain real
user data, every schema change must preserve installed databases through tested
step-up migrations.
