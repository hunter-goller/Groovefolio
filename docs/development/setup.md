# Development Setup

## Prerequisites

- Git
- Flutter stable
- Dart compatible with the project's `^3.12.2` constraint
- Android SDK and an emulator or physical Android device
- VS Code, Android Studio, or another Flutter-capable editor

The initial product target is Android. Other Flutter runners are present but are
not yet treated as supported release platforms.

## Clone and install

```bash
git clone https://github.com/hunter-goller/vinyl-app.git
cd vinyl-app
flutter doctor
flutter pub get
```

Resolve any required Android toolchain items reported by `flutter doctor`.

## Generate source

Generated Riverpod and Drift files are ignored by Git and must be created
locally:

```bash
dart run build_runner build --delete-conflicting-outputs
```

See [code generation](code-generation.md).

## Verify the project

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

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
dart run build_runner build --delete-conflicting-outputs

# Before committing
dart format .
flutter analyze
flutter test
```

## Database location

Production uses a file named `vinyl_app_db.sqlite` in the platform application
documents directory. Automated database tests use in-memory SQLite and do not
write to the device filesystem.

## Resetting local development data

While schema migration support is still under development, uninstalling the app
or clearing its application data removes the local development database. Do not
use this approach after public releases contain real user data.
